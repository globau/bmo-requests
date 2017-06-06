#!/usr/bin/env perl
use local::lib;

use Mojolicious::Lite;

use Date::Parse qw( str2time );
use FindBin qw( $RealBin );
use Mojo::ByteStream;
use Mojo::JSON qw( j );
use Mojo::URL;
use Mojo::UserAgent;
use Try::Tiny;

plugin 'basic_auth';  # Mojolicious::Plugin::BasicAuth

app->secrets('!requests!');
$0 = 'requests.app';
if (($ARGV[0] // '') eq 'daemon' && app->mode eq 'production') {
    Mojo::File->new("$RealBin/requests.app.pid")->spurt("$$\n");
}

my ($login, $api_key);

under sub {
    my $c = shift;
    return unless $c->basic_auth(
        'bmo-requests' => sub {
            return unless @_;
            ($login, $api_key) = @_;
            return unless $login =~ /^.+\@.+$/;
            $c->stash( login => $login );
            return 1;
        }
    );
};

get '/' => 'index';
get '/get' => \&_get;

helper javascript_file => sub {
    my ($c, $file) = @_;
    my $mtime = app->static->file($file)->mtime;
    return Mojo::ByteStream->new(
        '<script src="' . $file . '?' . $mtime . '"></script>'
    );
};

helper stylesheet_file => sub {
    my ($c, $file) = @_;
    my $mtime = app->static->file($file)->mtime;
    return Mojo::ByteStream->new(
        '<link href="' . $file . '?' . $mtime . '" rel="stylesheet">'
    );
};

app->start;

sub _get {
    my ($app) = @_;
    my $response = {};
    try {
        my $ua = Mojo::UserAgent->new( name => 'glob.uno/requests' );
        my $url;

        # bugs
        $url = Mojo::URL->new('https://bugzilla.mozilla.org/rest/bug');
        $url->query(
            api_key => $api_key,
            include_fields => 'id,summary,flags',
            f1 => 'requestees.login_name',
            o1 => 'equals',
            v1 => $login,
        );
        my $bugs = $ua->get($url)->res->json('/bugs');

        # attachments
        foreach my $bug (@$bugs) {
            $url = Mojo::URL->new('https://bugzilla.mozilla.org/rest/bug/' . $bug->{id} . '/attachment');
            $url->query(
                api_key => $api_key,
                include_fields => 'description,flags,id,is_patch',
            );
            $bug->{attachments} = $ua->get($url)->res->json('/bugs/' . $bug->{id});
        }

        # flatten
        my @result;
        foreach my $bug (@$bugs) {
            foreach my $attachment (@{ $bug->{attachments} }) {
                foreach my $flag (@{ $attachment->{flags} }) {
                    next unless $flag->{requestee} && $flag->{requestee} eq $login;
                    push @result, {
                        bug_id => $bug->{id},
                        bug_desc => $bug->{summary},
                        attach_id => $attachment->{id},
                        attach_desc => $attachment->{description},
                        attach_is_patch => $attachment->{is_patch},
                        flag_who => $flag->{setter},
                        flag_name => $flag->{name},
                        flag_when => str2time($flag->{creation_date}),
                    };
                }
            }
            if ($bug->{flags}) {
                foreach my $flag (@{ $bug->{flags} }) {
                    next unless $flag->{requestee} && $flag->{requestee} eq $login;
                    push @result, {
                        bug_id => $bug->{id},
                        bug_desc => $bug->{summary},
                        flag_who => $flag->{setter},
                        flag_name => $flag->{name},
                        flag_when => str2time($flag->{creation_date}),
                    };
                }
            }
        }
        $response->{flags} = [
            sort { $a->{flag_when} <=> $b->{flag_when} }
            @result
        ];

    } catch {
        $response = { error => $_ };
    };
    $app->render( text => j($response), format => 'json' );
};