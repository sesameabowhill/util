package com.sesamecom.util;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import org.junit.Test;

import static org.hamcrest.CoreMatchers.equalTo;
import static org.junit.Assert.assertThat;

/**
 *
 */
public class TemplateToolkitTextTest {

    @Test
    public void testSimpleTemplate() {
        TemplateToolkitText text = new TemplateToolkitText("[% Patient_First_Name %] has an appointment " +
                "in our [% Office_Location %]");
        String result = text.renderWithParams(new ImmutableMap.Builder<String, Object>()
                .put("Patient_First_Name", "Dana")
                .put("Office_Location", "office")
                .build());
        assertThat(result, equalTo("Dana has an appointment in our office"));
    }

    @Test
    public void testLoopTemplate() {
        { // short loop variables
            TemplateToolkitText template = new TemplateToolkitText("Patients [% FOREACH list %]" +
                    "[% name %][% UNLESS loop.last(); ', '; END; %][% END %]");
            String result = template.renderWithParams(new ImmutableMap.Builder<String, Object>()
                    .put("list", ImmutableList.of(
                            ImmutableMap.of("id", "1", "name", "Jason"),
                            ImmutableMap.of("id", "2", "name", "Dana")))
                    .build());
            assertThat(result, equalTo("Patients Jason, Dana"));
        }
        { // normal loop
            TemplateToolkitText template = new TemplateToolkitText("Patients [% FOREACH l IN list %]" +
                    "[% l.name %][% UNLESS loop.last(); ', '; END; %][% END %]");
            String result = template.renderWithParams(new ImmutableMap.Builder<String, Object>()
                    .put("list", ImmutableList.of(
                            ImmutableMap.of("id", "1", "name", "Jason"),
                            ImmutableMap.of("id", "2", "name", "Dana")))
                    .build());
            assertThat(result, equalTo("Patients Jason, Dana"));
        }
    }

    @Test
    public void testElseIf() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("[% IF size=='small' %]" +
                "<[% img %]/small>" +
                "[% ELSIF size=='medium' %]" +
                "<[% img %]/medium>" +
                "[% ELSE %]" +
                "<[% img %]/full>" +
                "[% END %]");
        assertThat(template.renderWithParams(ImmutableMap.of("size", (Object)"small", "img", "prefix")),
                equalTo("<prefix/small>"));
        assertThat(template.renderWithParams(ImmutableMap.of("size", (Object)"medium", "img", "prefix")),
                equalTo("<prefix/medium>"));
        assertThat(template.renderWithParams(ImmutableMap.of("size", (Object)"full", "img", "prefix")),
                equalTo("<prefix/full>"));
    }

    @Test
    public void testElseIfWithNewLineInCondition() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("[% IF size=='small'\n\n %]" +
                "<[% img %]/small>" +
                "[% ELSIF size=='medium'\n\n %]" +
                "<[% img %]/medium>" +
                "[% ELSE %]" +
                "<[% img %]/full>" +
                "[% END %]");
        assertThat(template.renderWithParams(ImmutableMap.of("size", (Object)"small", "img", "prefix")),
                equalTo("<prefix/small>"));
        assertThat(template.renderWithParams(ImmutableMap.of("size", (Object)"medium", "img", "prefix")),
                equalTo("<prefix/medium>"));
        assertThat(template.renderWithParams(ImmutableMap.of("size", (Object)"full", "img", "prefix")),
                equalTo("<prefix/full>"));
    }

    @Test
    public void testVariableFilters() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("escaped html: [% body | html %]");
        assertThat(template.renderWithParams(ImmutableMap.of("body", (Object)"<br>")),
                equalTo("escaped html: &lt;br&gt;"));
    }

    @Test
    public void testConditionsWithBoolean() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("(A|B)&C: (" +
                "[% IF A %]true[% ELSE %]false[% END %], " +
                "[% IF B %]true[% ELSE %]false[% END %], " +
                "[% IF C %]true[% ELSE %]false[% END %]) -> " +
                "[% IF (A || B) && C %]true[% ELSE %]false[% END %]");
        assertThat(template.renderWithParams(ImmutableMap.of("A", (Object)true, "B", true, "C", true)),
                equalTo("(A|B)&C: (true, true, true) -> true"));
        assertThat(template.renderWithParams(ImmutableMap.of("A", (Object)true, "B", true, "C", false)),
                equalTo("(A|B)&C: (true, true, false) -> false"));
        assertThat(template.renderWithParams(ImmutableMap.of("A", (Object)true, "B", false, "C", true)),
                equalTo("(A|B)&C: (true, false, true) -> true"));
    }

    @Test
    public void testDefinedConditionForString() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("string: [% IF !! string %][% string %][% ELSE %]no value[% END %]");
        assertThat(template.renderWithParams(ImmutableMap.of("string", (Object)"smile")),
                equalTo("string: smile"));
        assertThat(template.renderWithParams(ImmutableMap.of("string", (Object)"")),
                equalTo("string: no value"));
    }

    @Test
    public void testDefinedConditionForStringWithNewLineInCondition() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("string: [% IF ! A %]\n" +
                "[% ELSIF (A && !! string) || \n(!A) %]" +
                "[% string %][% ELSE %]no value[% END %]");
        assertThat(template.renderWithParams(ImmutableMap.of("string", (Object)"smile", "A", true)),
                equalTo("string: smile"));
        assertThat(template.renderWithParams(ImmutableMap.of("string", (Object)"", "A", true)),
                equalTo("string: no value"));
    }

    @Test
    public void testDefinedConditionWithOthers() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("(A|B)&C: (" +
                "[% IF A %]true[% ELSE %]false[% END %], " +
                "[% IF B %]true[% ELSE %]false[% END %], " +
                "[% IF C?? %][% C %][% ELSE %]<undefined>[% END %]) -> " +
                "[% IF (A || B) && !! C %]true[% ELSE %]false[% END %]");
        assertThat(template.renderWithParams(ImmutableMap.of("A", (Object)true, "B", true, "C", "true")),
                equalTo("(A|B)&C: (true, true, true) -> true"));
        assertThat(template.renderWithParams(ImmutableMap.of("A", (Object)true, "B", true, "C", "")),
                equalTo("(A|B)&C: (true, true, ) -> false"));
        assertThat(template.renderWithParams(ImmutableMap.of("A", (Object)true, "B", true)),
                equalTo("(A|B)&C: (true, true, <undefined>) -> false"));
        assertThat(template.renderWithParams(ImmutableMap.of("A", (Object)true, "B", false, "C", "true")),
                equalTo("(A|B)&C: (true, false, true) -> true"));
    }

    @Test
    public void testIgnoreCollapseFilter() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("pre: [% FILTER collapse %]inner: " +
                "[% string %][% IF skip %]skip[% END %] :suffix[% END %]");
        assertThat(template.renderWithParams(ImmutableMap.of("string", (Object)"true", "skip", false)),
                equalTo("pre: inner: true :suffix"));

    }

    @Test
    public void testVariableAssignment() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("[% DEFAULT style='style=\"color;border\"' %]" +
                "[% address = \"address\" %]" +
                "[% IF action==\"preview\"; style='preview color;preview border';\n" +
                "       address=\"preview address\" %]" +
                "[% END %]style: [% style %], address: [% address %]");
        assertThat(template.renderWithParams(ImmutableMap.of("action", (Object)"")),
                equalTo("style: style=\"color;border\", address: address"));
        assertThat(template.renderWithParams(ImmutableMap.of("action", (Object)"preview")),
                equalTo("style: preview color;preview border, address: preview address"));
    }

    @Test
    public void testIgnoreComment() throws Exception {
        TemplateToolkitText template = new TemplateToolkitText("[% # $Header:$ %][% action %]");
        assertThat(template.renderWithParams(ImmutableMap.of("action", (Object)"preview")),
                equalTo("preview"));
    }
}
