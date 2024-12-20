use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::PAUSE::Web;
use File::Path qw/rmtree mkpath/;
use File::Spec;
use Mojo::File qw/path/;
use utf8;

my $http_upload = {
    pause99_add_uri_httpupload => ["$Test::PAUSE::Web::AppRoot/htdocs/index.html", "index.html"],
    SUBMIT_pause99_add_uri_httpupload => 1,
};

my $uri_upload = {
    pause99_add_uri_uri => "file://".File::Spec->rel2abs(__FILE__),
    SUBMIT_pause99_add_uri_uri => 1,
};

Test::PAUSE::Web->setup;

subtest 'get' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        $t->get_ok("$path?ACTION=add_uri");
        # note $t->content;
    }
};

subtest 'get: user with subdirs' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $user_home = $PAUSE::Config->{MLROOT}."/".PAUSE::user2dir($user);
        my $subdir = path("$user_home/test");
        $subdir->make_path;
        $subdir->child("stuff.txt")->spew("Foo");

        my $t = Test::PAUSE::Web->new(user => $user);
        $t->get_ok("$path?ACTION=add_uri");
        $t->text_is('select[name="pause99_add_uri_subdirscrl"] option[value="."]', "."); # default
        $t->text_is('select[name="pause99_add_uri_subdirscrl"] option[value="test"]', "test");
        # note $t->content;
    }
};

subtest 'post: basic' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        my $file = $PAUSE::Config->{INCOMING_LOC}."/".$form{pause99_add_uri_httpupload}[1];
        ok !-f $file, "file to upload does not exist";

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        # note $t->content;

        ok -f $file, "uploaded file exists";
        unlink $file;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 1;
    }
};

subtest 'post: under a new subdir' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        $form{pause99_add_uri_subdirtext} = "new_dir";

        my $file = $PAUSE::Config->{INCOMING_LOC}."/".$form{pause99_add_uri_httpupload}[1];
        ok !-f $file, "file to upload does not exist";

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        # note $t->content;

        ok -f $file, "uploaded file exists";
        unlink $file;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 1;
        like $rows->[0]{uriid} => qr!/new_dir/!, "uriid contains /new_dir/";
    }
};

subtest 'post: under a Perl6 subdir' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        $form{pause99_add_uri_subdirscrl} = "Perl6";

        my $user_home = $PAUSE::Config->{MLROOT}."/".PAUSE::user2dir($user);
        my $subdir = path("$user_home/Perl6");
        $subdir->make_path;
        $subdir->child("stuff.txt")->spew("Foo");

        my $file = $PAUSE::Config->{INCOMING_LOC}."/".$form{pause99_add_uri_httpupload}[1];
        ok !-f $file, "file to upload does not exist";

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        # note $t->content;

        ok -f $file, "uploaded file exists";
        unlink $file;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 1;
        like $rows->[0]{uriid} => qr!/Perl6/!, "uriid contains /Perl6/";
        ok $rows->[0]{is_perl6};
    }
};

subtest 'post: empty' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        $form{pause99_add_uri_httpupload} = [undef, 'index.html'];

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        # note $t->content;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 0;
    }
};

subtest 'post: renamed' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        $form{pause99_add_uri_httpupload} = ["$Test::PAUSE::Web::AppRoot/htdocs/index.html", 'html/index.html'];
        my $file = $PAUSE::Config->{INCOMING_LOC}."/index.html";
        ok !-f $file, "file to upload does not exist";

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        # note $t->content;

        # renamed file exists
        ok -f $file, "uploaded file exists";
        unlink $file;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => "index.html",
        });
        is @$rows => 1;
    }
};

subtest 'post: uri' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$uri_upload;

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        # note $t->content;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_uri},
        });
        is @$rows => 1;
    }
};

subtest 'post: CHECKSUMS' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        $form{pause99_add_uri_httpupload} = ["$Test::PAUSE::Web::AppRoot/htdocs/index.html", "CHECKSUMS"],

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        $t->text_like('.error_message' => qr/Files with the name CHECKSUMS cannot be/);
        # note $t->content;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 0;
    }
};

subtest 'post: allow overwrite' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        my $file = $PAUSE::Config->{INCOMING_LOC}."/".$form{pause99_add_uri_httpupload}[1];
        ok !-f $file, "file to upload does not exists";

        $t->mod_dbh->do('TRUNCATE uris');
        for (0 .. 1) {
            $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
            # note $t->content;

            # uploaded file exists
            ok -f $file, "uploaded file exists";
            unlink $file;
        }

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 1;
    }
};

subtest 'post: duplicate' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        $form{pause99_add_uri_httpupload} = ["$Test::PAUSE::Web::AppRoot/htdocs/index.html", "index.tar.gz"],
        my $file = $PAUSE::Config->{INCOMING_LOC}."/".$form{pause99_add_uri_httpupload}[1];
        ok !-f $file, "file to upload does not exist";

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        # note $t->content;

        ok -f $file, "uploaded file exists";
        unlink $file;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 1;

        my $res = $t->post("$path?ACTION=add_uri", \%form, "Content-Type" => "form-data");
        is $res->code => 409;
        # note $t->content;

        ok -f $file, "uploaded file exists";
        unlink $file;

        $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 1;
    }
};

subtest 'post: to the site top, as various CPAN uploaders do/did' => sub {
    for my $test (Test::PAUSE::Web->tests_for('user')) {
        my ($path, $user) = @$test;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = %$http_upload;
        my $file = $PAUSE::Config->{INCOMING_LOC}."/".$form{pause99_add_uri_httpupload}[1];
        ok !-f $file, "file to upload does not exist";

        $t->mod_dbh->do('TRUNCATE uris');
        $t->post_ok("$path", \%form, "Content-Type" => "form-data");
        # note $t->content;

        ok -f $file, "uploaded file exists";
        unlink $file;

        my $rows = $t->mod_db->select('uris', ['*'], {
            userid => $user,
            uri => $form{pause99_add_uri_httpupload}[1],
        });
        is @$rows => 1;
    }
};

subtest 'post: upload size limit' => sub {
    my $small_file = "$Test::PAUSE::Web::AppRoot/t/data/files/somefile.txt";
    my $large_file = "$Test::PAUSE::Web::AppRoot/t/dist/My-Dist.yaml";
    my $max_size = 10485760;

    my $test_upload = sub {
        my ($user, $file, $expected_status) = @_;
        my $t = Test::PAUSE::Web->new(user => $user);
        my %form = (
            pause99_add_uri_httpupload => [$file, path($file)->basename],
            SUBMIT_pause99_add_uri_httpupload => 1,
        );

        $t->mod_dbh->do('TRUNCATE uris');
        my $res = $t->post("/pause/authenquery?ACTION=add_uri", \%form, "Content-Type" => "form-data");

        if ($expected_status == 200) {
            $t->status_is($expected_status);
            my $uploaded_file = $PAUSE::Config->{INCOMING_LOC} . "/" . path($file)->basename;
            ok -f $uploaded_file, "uploaded file exists";
            unlink $uploaded_file;
        } else {
            $t->status_is($expected_status);
            $t->text_like('.error_message' => qr/Upload size exceeds limit/);
        }
    };

    $test_upload->('ANDK', $small_file, 200);
    $test_upload->('ANDK', $large_file, 406);



    $test_upload->('UPLOADSIZE', $large_file, 200);
    $test_upload->('PUMPKIN', $large_file, 200);
};


done_testing;

