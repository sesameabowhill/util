package com.sesamecom.util;

import com.google.common.collect.Lists;
import freemarker.cache.StringTemplateLoader;
import freemarker.template.Configuration;
import freemarker.template.Template;
import freemarker.template.TemplateException;

import java.io.IOException;
import java.io.StringWriter;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.google.common.base.Preconditions.checkNotNull;

/**
 * This class converts Template Toolkit template string to FreeMarker equivalent.
 * Syntax parsing is done to convert same END to different directives.
 * Not all directives are supported
 */
public class TemplateToolkitText {
    private static final Pattern tt_command_placeholder = Pattern.compile("\\[%(.*?)%\\]", Pattern.DOTALL);
    private static final Pattern tt_command = Pattern.compile("^(?:FILTER|END|FOR|FOREACH|IF|UNLESS|ELSE|ELSIF)");
    private static final Pattern tt_variable_with_filter = Pattern.compile("^([\\w\\.]+)(?:\\s+\\|\\s+(\\w+))?$");
    private static final Pattern tt_is_perl_true_check = Pattern.compile("!!\\s*([\\w\\.]+)");
    private static final Pattern tt_string = Pattern.compile("^['\"](.*)['\"]$"); // doesn't check if quotes matched
    private static final Pattern tt_foreach = Pattern.compile("^FOR(?:EACH)?\\s+(\\w+)(?:\\s+IN\\s+(\\w+))?$");
    private static final Pattern tt_if = Pattern.compile("^IF\\s+(.+)$", Pattern.DOTALL);
    private static final Pattern tt_elsif = Pattern.compile("^ELSIF\\s+(.+)$", Pattern.DOTALL);
    private static final Pattern tt_end = Pattern.compile("^END$");
    private static final Pattern tt_else = Pattern.compile("^ELSE$");
    private static final Pattern tt_unless = Pattern.compile("^UNLESS\\s+(.+)$", Pattern.DOTALL);
    private static final Pattern tt_filter = Pattern.compile("^FILTER\\s+(.+)$");
    private static final Pattern tt_assign_variable = Pattern.compile("^(?:DEFAULT\\s+)?([\\w\\.]+)\\s*=\\s*(.*)$", Pattern.DOTALL);
    private static final String DEFAULT_TEMPLATE_NAME = "default";

    private String text;
    private String convertedTemplate;
    private Configuration templateConfiguration;

    public TemplateToolkitText(String text) {
        StringTemplateLoader templateLoader = new StringTemplateLoader();
        templateConfiguration = new Configuration();
        templateConfiguration.setTemplateLoader(templateLoader);
        //templateConfiguration.setObjectWrapper(ObjectWrapper.BEANS_WRAPPER);
        this.text = text;
        this.convertedTemplate = convertTemplateFromPerlFormat(text);
        templateLoader.putTemplate(DEFAULT_TEMPLATE_NAME, convertedTemplate);
    }

    /**
     * Render template using parameters and return result as string. See
     * http://freemarker.sourceforge.net/docs/pgui_quickstart_createdatamodel.html
     * @param params can be any combination of List, Map, Boolean, Number, String
     * @return Rendered template string
     */
    public String renderWithParams(Map<String, Object> params) {
        StringWriter stringWriter = new StringWriter();
        try {
            Template template = templateConfiguration.getTemplate(DEFAULT_TEMPLATE_NAME);
            template.process(params, stringWriter);
        } catch (TemplateException e) {
            throw new RuntimeException("error processing [" + convertedTemplate + "] (original template [" + text + "])", e);
        } catch (IOException e) {
            throw new RuntimeException("error processing [" + convertedTemplate + "] (original template [" + text + "])", e);
        }
        return stringWriter.toString();
    }

    private String convertTemplateFromPerlFormat(String text) {
        List<Token> tokens = convertConditionsToLoopSeparator(convertEndTokensToRightOnes(
                splitToTokens(text, tt_command_placeholder)));
        return makeStringTemplate(tokens);
    }

    private List<Token> convertEndTokensToRightOnes(List<Token> tokens) {
        List<Token> result = Lists.newLinkedList();
        LinkedList<BlockCommand> commandStack = Lists.newLinkedList();
        for (Token token : tokens) {
            if (!token.isEmpty()) {
                if (token instanceof BlockCommand) {
                    commandStack.add((BlockCommand)token);
                    result.add(token);
                } else if (token instanceof EndCommand) {
                    if (commandStack.size() > 0) {
                        result.add(commandStack.removeLast().getCommandEnd());
                    } else {
                        // looks like unbalanced END tag, ignore it
                        result.add(token);
                    }
                } else {
                    result.add(token);
                }
            }
        }
        return result;
    }

    private List<Token> convertConditionsToLoopSeparator(List<Token> tokens) {
        List<Token> result = Lists.newLinkedList();
        Token skipUntilEndOf = null;
        LinkedList<LoopCommand> loopStack = Lists.newLinkedList();
        for (Token token : tokens) {
            if (null == skipUntilEndOf) {
                if (token instanceof IfCommand) {
                    if (((IfCommand)token).isLoopCondition()) {
                        skipUntilEndOf = token;
                    } else {
                        result.add(token);
                    }
                } else if (token instanceof LoopCommand) { // add loop stack frame
                    loopStack.add((LoopCommand)token);
                    result.add(token);
                } else if (token instanceof LoopEndCommand) { // remove loop stack frame
                    loopStack.removeLast();
                    result.add(token);
                } else if (token instanceof Variable) {
                    Variable variable = (Variable)token;
                    if (loopStack.size() > 0 && loopStack.getLast().isShortMode() && ! variable.hasPrefix()) {
                        variable.addPrefix(loopStack.getLast().getVariable());
                    }
                    result.add(token);
                } else {
                    result.add(token);
                }
            } else {
                if (token instanceof EndCommand) {
                    if (((EndCommand)token).isEndFor(skipUntilEndOf)) {
                        skipUntilEndOf = null;
                    }
                } else if (token instanceof Text) {
                    // if we inside condition checking "loop" variable then we put any text to separator
                    if (loopStack.size() > 0) {
                        loopStack.getLast().setSeparator(((Text)token).getText());
                    }
                }
            }
        }
        return result;
    }

    private String makeStringTemplate(List<Token> tokens) {
        StringBuilder result = new StringBuilder();
        for (Token token : tokens) {
            result.append(token.toStringTemplate());
        }
        return result.toString();
    }

    private List<Token> splitToTokens(String text, Pattern tt_term) {
        Matcher matcher = tt_term.matcher(text);
        int lastTextPosition = 0;
        List<Token> tokens = Lists.newLinkedList();
        while (matcher.find()) {
            // save text before token
            tokens.add(new Text(text.substring(lastTextPosition, matcher.start())));
            lastTextPosition = matcher.end();
            String command = matcher.group(1).trim();
            for (String innerCommand : getInnerCommands(command)) {
                Matcher stringMatcher = tt_string.matcher(innerCommand);
                if (stringMatcher.find()) {
                    // convert back to text if it's just a quoted string
                    tokens.add(new Text(stringMatcher.group(1)));
                } else {
                    tokens.add(Token.getTokensByString(innerCommand));
                }
            }
        }
        // save last piece of text
        tokens.add(new Text(text.substring(lastTextPosition)));
        return tokens;
    }

    /**
     * Split string by command separator ignoring if it's in quotes
     * @param command to split
     * @return list of individual commands
     */
    private List<String> getInnerCommands(String command) {
        boolean isInQuote = false;
        boolean isInComment = false;
        char quoteChar = 0;
        StringBuilder currentCommand = new StringBuilder();
        List<String> commands = Lists.newLinkedList();
        for (int charIndex = 0; charIndex < command.length(); ++charIndex) {
            char currentChar = command.charAt(charIndex);
            if (isInComment) {
                if (currentChar == '\n') { // stop comment on new line
                    isInComment = false;
                }
            } else {
                if (isInQuote) {
                    if (currentChar == quoteChar) {
                        isInQuote = false;
                    }
                    currentCommand.append(currentChar); // capture symbol in quotes
                } else {
                    if (currentChar == '"' || currentChar == '\'') {
                        quoteChar = currentChar;
                        isInQuote = true;
                        currentCommand.append(currentChar); // capture last quote symbol
                    } else if (currentChar == ';') {
                        if (currentCommand.length() > 0) {
                            commands.add(currentCommand.toString().trim());
                            currentCommand = new StringBuilder();
                        }
                    } else if (currentChar == '#') {
                        isInComment = true;
                    } else {
                        currentCommand.append(currentChar); // capture all other characters
                    }
                }
            }
        }
        if (currentCommand.length() > 0) {
            commands.add(currentCommand.toString().trim());
        }
        return commands;
    }

    static private class Token {
        protected String text;

        public Token(String text) {
            this.text = text;
        }

        @Override
        public String toString() {
            return text;
        }

        public String toStringTemplate() {
            return toString();
        }

        public static Token getTokensByString(String command) {
            Matcher assignVariableMatcher = tt_assign_variable.matcher(command);
            Matcher variableMatcher = tt_variable_with_filter.matcher(command);
            if (tt_command.matcher(command).find()) {
                Matcher commandMatcher = tt_foreach.matcher(command);
                if (commandMatcher.find()) {
                    if (null == commandMatcher.group(2)) {
                        return new LoopCommand(command, commandMatcher.group(1), null);
                    } else {
                        return new LoopCommand(command, commandMatcher.group(2), commandMatcher.group(1));
                    }
                }
                commandMatcher = tt_if.matcher(command);
                if (commandMatcher.find()) {
                    return new IfCommand(command, commandMatcher.group(1));
                }
                commandMatcher = tt_unless.matcher(command);
                if (commandMatcher.find()) {
                    return new UnlessCommand(command, commandMatcher.group(1));
                }
                commandMatcher = tt_elsif.matcher(command);
                if (commandMatcher.find()) {
                    return new ElseIfCommand(command, commandMatcher.group(1));
                }
                commandMatcher = tt_else.matcher(command);
                if (commandMatcher.find()) {
                    return new ElseCommand(command);
                }
                commandMatcher = tt_filter.matcher(command);
                if (commandMatcher.find()) {
                    return new FilterCommand(command, commandMatcher.group(1));
                }
                commandMatcher = tt_end.matcher(command);
                if (commandMatcher.find()) {
                    return new EndCommand(null); // will be replaced by specific end statement
                }
            } else if (assignVariableMatcher.find()) {
                return new AssignCommand(assignVariableMatcher.group(1), assignVariableMatcher.group(2));
            } else if (variableMatcher.find()) {
                if (null == variableMatcher.group(2)) {
                    return new Variable(command);
                } else {
                    return new VariableWithFilter(variableMatcher.group(1), variableMatcher.group(2));
                }
            }
            return new UnknownCommand(command); // unknown command
        }

        public boolean isEmpty() {
            return text.length() == 0;
        }
    }

    static private class UnknownCommand extends Token {
        public UnknownCommand(String text) {
            super(text);
        }

        @Override
        public String toString() {
            return isEmpty() ? "" : "[% " + text + " %]";
        }

        protected static String convertCondition(String condition) {
            Matcher isPerlTrueCheck = tt_is_perl_true_check.matcher(condition);
            condition = isPerlTrueCheck.replaceAll("($1?? && 0 < $1?length)");
            return condition;
        }

    }

    static private class AssignCommand extends Token {
        private AssignCommand(String variable, String expression) {
            super(variable + " = " + expression);
        }

        @Override
        public String toStringTemplate() {
            return "<#assign " + text + ">";
        }
    }

    static private class EndCommand extends UnknownCommand {
        protected UnknownCommand startCommand;

        public EndCommand(UnknownCommand command) {
            super("END");
            this.startCommand = command;
        }

        public boolean isEndFor(Token token) {
            return startCommand != null && startCommand == token;
        }
    }

    static private class FilterEndCommand extends EndCommand {
        private FilterEndCommand(UnknownCommand command) {
            super(command);
        }

        @Override
        public String toStringTemplate() {
            return ""; // ignore filters
        }
    }

    static private class IfEndCommand extends EndCommand {

        private IfEndCommand(IfCommand command) {
            super(command);
        }

        @Override
        public String toStringTemplate() {
            return "</#if>";
        }
    }

    static private class LoopEndCommand extends EndCommand {
        public LoopEndCommand(LoopCommand loopCommand) {
            super(loopCommand);
        }

        @Override
        public String toStringTemplate() {
            String separator = ((LoopCommand)startCommand).getSeparator();
            return (null == separator ? "" : "<#if "
                    + ((LoopCommand)startCommand).getVariable() + "_has_next>" + separator + "</#if>")
                    + "</#list>";
        }
    }

    static private interface BlockCommand  {
        abstract public EndCommand getCommandEnd();
    }

    static private class IfCommand extends UnknownCommand implements BlockCommand {
        protected String condition;

        private IfCommand(String text, String condition) {
            super(text);
            this.condition = condition;
        }

        @Override
        public String toStringTemplate() {
            return "<#if " + UnknownCommand.convertCondition(condition) + ">";
        }

        @Override
        public EndCommand getCommandEnd() {
            return new IfEndCommand(this);
        }

        public boolean isLoopCondition() {
            return condition.startsWith("loop.");
        }
    }

    static private class FilterCommand extends UnknownCommand implements BlockCommand {
        protected String filterName;

        private FilterCommand(String text, String filterName) {
            super(text);
            this.filterName = filterName;
        }

        @Override
        public String toStringTemplate() {
            return ""; // ignore filter
        }

        @Override
        public EndCommand getCommandEnd() {
            return new FilterEndCommand(this);
        }
    }

    static private class UnlessCommand extends IfCommand {
        private UnlessCommand(String text, String condition) {
            super(text, condition);
        }

        @Override
        public String toStringTemplate() {
            return "<#if !(" + UnknownCommand.convertCondition(condition) + ")>";
        }
    }

    static private class ElseIfCommand extends UnknownCommand {
        private String condition;
        private ElseIfCommand(String text, String condition) {
            super(text);
            this.condition = condition;
        }

        @Override
        public String toStringTemplate() {
            return "<#elseif " + UnknownCommand.convertCondition(condition) + ">";
        }
    }

    static private class ElseCommand extends UnknownCommand {
        private ElseCommand(String text) {
            super(text);
        }

        @Override
        public String toStringTemplate() {
            return "<#else>";
        }
    }

    static private class LoopCommand extends UnknownCommand implements BlockCommand {
        private String in;
        private String separator;
        private String variable;
        private boolean shortMode;

        private LoopCommand(String text, String in, String variable) {
            super(text);
            this.in = in;
            this.shortMode = (null == variable);
            this.variable = (null == variable ? in + "_elem" : variable );
            this.separator = null;
        }

        @Override
        public String toStringTemplate() {
            return "<#list " + in + " as " + (null == variable ? "" : variable ) + ">";
        }

        @Override
        public EndCommand getCommandEnd() {
            return new LoopEndCommand(this);
        }

        public String getSeparator() {
            return separator;
        }

        public void setSeparator(String separator) {
            checkNotNull(separator);
            this.separator = separator;
        }

        public boolean isShortMode() {
            return shortMode;
        }

        public String getVariable() {
            return variable;
        }
    }

    static private class Variable extends Text {
        public Variable(String text) {
            super(text);
        }

        @Override
        public String toString() {
            return "[% " + text + " %]";
        }

        @Override
        public String toStringTemplate() {
            return "${" + text + "}";
        }

        public boolean hasPrefix() {
            return text.contains(".");
        }

        public void addPrefix(String prefix) {
            text = prefix + "." + text;
        }
    }

    static private class VariableWithFilter extends Text {
        private String filter;

        private VariableWithFilter(String text, String filter) {
            super(text);
            this.filter = filter;
        }

        @Override
        public String toString() {
            return "[% " + text + " | " + filter + " %]";
        }

        @Override
        public String toStringTemplate() {
            return "${" + text + "?" + getFilterByString(filter, text) + "}";
        }

        static private String getFilterByString(String tt_filter, String text) {
            if ("html".equals(tt_filter) || "html_entity".equals(tt_filter)) {
                return "html";
            } else {
                throw new RuntimeException("unknown filter [" + tt_filter + "] in [" + text + "]");
            }
        }
    }

    static private class Text extends Token {
        public Text(String text) {
            super(text);
        }

        @Override
        public String toStringTemplate() {
            return text.replaceAll("<", "\\<");
        }

        public String getText() {
            return text;
        }
    }
}
