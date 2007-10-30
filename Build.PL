use Module::Build;

my $build = Module::Build->new(
	module_name		=> 'Finance::Bank::Schwab',
	license			=> 'perl',
	create_readme	=> 1,
    create_makefile_pl      => 'passthrough',
	requires		=> {
						'Carp'				=> 0,
						'WWW::Mechanize'	=> 1.00,
					   },
);
$build->create_build_script;

