# kind of duplicate of Makefile.PL
#	but convenient for Continuous Integration

requires 'IPC::System::Simple' => 0;
requires 'parent' => 0;
requires 'BSD::Resource' => 0 if $^O ne 'MSWin32';

on 'test' => sub {
    requires 'Test::Perl::Critic' => 0 if $] > 5.011;
    requires 'Import::Into' => 0;
    requires 'Sub::Identify' => 0;
    requires 'Test::Pod::Coverage' => 0  => 0 if $] > 5.011;
    requires 'Test::Pod' => 0;
    requires 'Test::More' => 0;   
};
