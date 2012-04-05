## $Header$
package PDMParser;

use strict;
use warnings;

use Tie::IxHash;
use XML::LibXML;

sub new {
        my ($class, $file_name) = @_;

        my $parser = XML::LibXML->new();
        my $doc = $parser->parse_file($file_name);

        return bless {
                'doc' => $doc,
        }, $class;
}

sub save {
        my ($self, $file_name) = @_;

        $self->{'doc'}->toFile($file_name);
}

sub get_comment {
        my ($self) = @_;

        my (@model_nodes) = $self->{'doc'}->getElementsByTagName("o:Model");
        return _get_element_text($model_nodes[0], "a:Comment");
}

sub set_table_name {
        my ($self, $table_id, $table_name) = @_;

        die "call [get_tables] method first" unless exists $self->{'table_nodes'};

        $self->_set_inner_element_text($self->{'table_nodes'}{$table_id}, "a:Name", $table_name);
        $self->_set_inner_element_text($self->{'table_nodes'}{$table_id}, "a:Code", $table_name);
}

sub set_table_comment {
        my ($self, $table_id, $comment) = @_;

        die "call [get_tables] method first" unless exists $self->{'table_nodes'};

        $self->_set_inner_element_text($self->{'table_nodes'}{$table_id}, "a:Comment", $comment);
}

sub set_column_comment {
        my ($self, $column_id, $comment) = @_;

        die "call [get_tables] method first" unless exists $self->{'column_nodes'};

        $self->_set_inner_element_text($self->{'column_nodes'}{$column_id}, "a:Comment", $comment);
}


sub _set_inner_element_text {
        my ($self, $doc, $element_name, $text) = @_;

        my ($elem) = $doc->getElementsByTagName($element_name);
        if (defined $elem) {
                $elem->removeChildNodes();
                $elem->appendText($text);
        } else {
                my $comment_node = $self->{'doc'}->createElement($element_name);
                $comment_node->appendText($text);
                $doc->addChild($comment_node);
        }
}

sub get_references {
        my ($self) = @_;

        tie my %references, 'Tie::IxHash';

        my ($doc) = $self->{'doc'}->getElementsByTagName("c:References");

        if (defined $doc) {
                for my $reference_nodes ($doc->getElementsByTagName("o:Reference")) {
                        my $object1_id = $reference_nodes->getElementsByTagName("c:ParentTable")->[0]->getElementsByTagName("o:Table")->[0]->getAttribute("Ref");
                        my $object2_id = $reference_nodes->getElementsByTagName("c:ChildTable")->[0]->getElementsByTagName("o:Table")->[0]->getAttribute("Ref");

                        my ($ref_join_node) = $reference_nodes->getElementsByTagName("o:ReferenceJoin");
                        if (defined $ref_join_node) {
                                my ($column1_node) = $ref_join_node->getElementsByTagName("c:Object1");
                                my ($column2_node) = $ref_join_node->getElementsByTagName("c:Object2");
                                if (!defined $column1_node || !defined $column2_node) {
                                        print "warning: wrong link [$object1_id] -> [$object2_id]\n";
                                }
                                my $column1_id = $column1_node->getElementsByTagName("o:Column")->[0]->getAttribute("Ref");
                                my $column2_id = $column2_node->getElementsByTagName("o:Column")->[0]->getAttribute("Ref");

                                my $reference_id = $reference_nodes->getAttribute("Id");
                                $references{ $reference_id } = {
                                        'to' => {
                                                'table_id'  => $object1_id,
                                                'column_id' => $column1_id,
                                        },
                                        'from' => {
                                                'table_id'  => $object2_id,
                                                'column_id' => $column2_id,
                                        },
                                };
                        } else {
                                print "warning: references [$object1_id] -> [$object2_id] don't have columns\n";
                        }
                }
        }
        return \%references;
}

sub get_tables {
        my ($self) = @_;

        my ($doc) = $self->{'doc'}->getElementsByTagName("c:Tables");

        tie my %tables, 'Tie::IxHash';
        for my $table_nodes ($doc->getElementsByTagName("o:Table")) {
                my $table_id = $table_nodes->getAttribute("Id");
                $self->{'table_nodes'}{ $table_id } = $table_nodes;
                my $table_name = _get_element_text($table_nodes, "a:Name");
                my ($columns) = $table_nodes->getElementsByTagName("c:Columns");
                $tables{ $table_id } = {
                        'name'       => $table_name,
                        'columns'    => $self->_get_columns($columns),
                        'comment'    => _get_element_text($table_nodes, "a:Comment"),
                        'attributes' => {},
                };

                my (@table_keys) = $table_nodes->getElementsByTagName("c:Keys");
                if (@table_keys) {
                        my $table_keys = _get_table_keys($table_keys[0]);
                        my @primary_key_nodes = $table_nodes->getElementsByTagName("c:PrimaryKey");

                        if (@primary_key_nodes) {
                                for my $primary_key_node ($primary_key_nodes[0]->getElementsByTagName("o:Key") ) {
                                        my $pk_column_ids = $table_keys->{ $primary_key_node->getAttribute("Ref") }{ 'columns' };
                                        for my $column_id (@$pk_column_ids) {
                                                $tables{ $table_id }{ 'columns' }{ $column_id }{ 'is_primary' } = 1;
                                        }
                                }
                        }
                }
        }
        return \%tables;
}

sub _get_columns {
        my ($self, $doc) = @_;

        tie my %columns, 'Tie::IxHash';
        for my $column_nodes ($doc->getElementsByTagName("o:Column")) {
                my $column_id = $column_nodes->getAttribute("Id");
                $columns{ $column_id } = {
                        'name'       => _get_element_text($column_nodes, "a:Name"),
                        'type'       => _get_element_text($column_nodes, "a:DataType"),
                        'length'     => _get_element_text($column_nodes, "a:Length"),
                        'default'    => _get_element_text($column_nodes, "a:DefaultValue"),
                        'is_null'    => ! _get_element_text($column_nodes, "a:Mandatory"),
                        'comment'    => _get_element_text($column_nodes, "a:Comment"),
                        'attributes' => {},
                };
                $self->{'column_nodes'}{ $column_id } = $column_nodes;
        }
        return \%columns;
}

sub _get_table_keys {
        my ($doc) = @_;

        tie my %table_keys, 'Tie::IxHash';
        for my $table_key_nodes ($doc->getElementsByTagName("o:Key")) {
                my $table_key_id = $table_key_nodes->getAttribute("Id");

                my @columns;
                my ($key_column_node) = $table_key_nodes->getElementsByTagName("c:Key.Columns");
                unless (defined $key_column_node) {
                        print "warning: no key columns for key [$table_key_id]\n";
                }
                for my $column_node ($key_column_node->getElementsByTagName("o:Column")) {
                        push( @columns, $column_node->getAttribute("Ref") );
                }

                $table_keys{ $table_key_id } = {
                        'name'    => _get_element_text($table_key_nodes, "a:Name"),
                        'columns' => \@columns,
                };
        }
        return \%table_keys;
}


sub _get_element_text {
        my ($doc, $elem_name) = @_;

        my @nodes = $doc->getElementsByTagName($elem_name);
        return @nodes ? $nodes[0]->textContent() : undef;
}

package PDMParser::Attributes;

sub new {
        my ($class, $attributes) = @_;

        return bless {
                'main_attributes'   => { map {$_ => 1} @{ $attributes->{'main'} } },
                'table_attributes'  => { map {$_ => 1} @{ $attributes->{'table'} } },
                'column_attributes' => { map {$_ => 1} @{ $attributes->{'column'} } },
        }, $class;
}

sub apply_all_attributes {
        my ($self, $comment, $tables) = @_;

        $self->_apply_main_attributes($comment, $tables);
        $self->_apply_table_attributes($tables);
        $self->_apply_column_attributes($tables);
}

sub _apply_main_attributes {
        my ($self, $comment, $tables) = @_;

        my %add_comment_to_column;
        my (undef, $main_attr) = _extract_attributes(
                $comment,
                {
                        'add_comment_to_column' => sub {
                                my ($params) = @_;

                                my ($column_name, $comment) = split(/:/, $params, 2);
                                $add_comment_to_column{ $column_name } = trim( $comment );
                        },
                }
        );

        while ( my ($attr_name, $attr_value) = each %$main_attr) {
                unless (exists $self->{'main_attributes'}{ $attr_name }) {
                        print "warning: unknown main attribute [$attr_name]\n";
                }
                for my $table (values %$tables) {
                        $table->{ 'attributes' }{ $attr_name } = $attr_value;
                }
        }

        if (keys %add_comment_to_column) {
                my %column_by_name;
                while ( my ($table_id, $table) = each %$tables) {
                        while ( my ($column_id, $column) = each %{ $table->{'columns'} }) {
                                $column_by_name{ $column->{'name'} }{ $table_id } = $column_id;
                        }
                }

                while ( my ($column_name, $comment) = each %add_comment_to_column) {
                        if (exists $column_by_name{ $column_name }) {
                                while ( my ($table_id, $column_id) = each %{ $column_by_name{ $column_name } }) {
                                        print "add_comment_to_column: column [$column_name] table [".$tables->{ $table_id }{'name'}."]\n";
                                        my $column = $tables->{ $table_id }{ 'columns' }{ $column_id };
                                        if (defined $column->{'comment'}) {
                                                $column->{'comment'} .= " " . $comment;
                                        } else {
                                                $column->{'comment'} = $comment;
                                        }
                                }
                        } else {
                                print "warning: add_comment_to_column: column [$column_name] is not found\n";
                        }
                }
        }
}

sub _apply_table_attributes {
        my ($self, $tables) = @_;

        for my $table (values %$tables) {
                if (defined $table->{'comment'}) {
                        my ($comment, $attributes) = _extract_attributes( $table->{'comment'} );
                        $table->{'comment'} = $comment;
                        while ( my ($attr_name, $attr_value) = each %$attributes) {
                                unless (exists $self->{'table_attributes'}{ $attr_name }) {
                                        print "warning: unknown table attribute [$attr_name] table [".$table->{'name'}."]\n";
                                }
                                $table->{ 'attributes' }{ $attr_name } = $attr_value;
                        }
                }
        }
}

sub _apply_column_attributes {
        my ($self, $tables) = @_;

        for my $table (values %$tables) {
                for my $column (values %{ $table->{'columns'} }) {
                        if (defined $column->{'comment'}) {
                                my ($comment, $attributes) = _extract_attributes( $column->{'comment'} );
                                $column->{'comment'} = $comment;
                                while ( my ($attr_name, $attr_value) = each %$attributes) {
                                        unless (exists $self->{'column_attributes'}{ $attr_name }) {
                                                print "warning: unknown column attribute [$attr_name] table [".$table->{'name'}."] column [".$column->{'name'}."]\n";
                                        }
                                        $column->{ 'attributes' }{ $attr_name } = $attr_value;
                                }
                        }
                }
        }
}


sub _extract_attributes {
        my ($text, $actions) = @_;
        $actions ||= {};

        my (@text, %attributes);
        for my $line ( split(/\r?\n/, $text) ) {
                if ($line =~ s/^!//) {
                        my ($attr_name, $attr_value) = split(/:/, $line, 2);
                        if (!defined $attr_value) {
                                $attr_value = 1;
                        }
                        if ($attr_name =~ s/^!//) {
                                $attr_name = trim($attr_name);
                                if (exists $actions->{ $attr_name }) {
                                        $actions->{ $attr_name }->( trim($attr_value) );
                                } else {
                                        print "warning: unknown action for [$attr_name]\n";
                                }
                        } else {
                                $attributes{ trim($attr_name) } =  $attr_value;
                        }
                } else {
                        push(@text, $line);

                }
        }
        return (join("\n", @text), \%attributes);
}

sub trim {
        my ($str) = @_;

        $str =~ s/^\s+//;
        $str =~ s/\s+$//;
        return $str;
}



1;

