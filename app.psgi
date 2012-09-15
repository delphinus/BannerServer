use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Amon2::Lite;
use Path::Class;
use Log::Minimal;
$Log::Minimal::AUTODUMP = 1;

our $VERSION = '0.01';

my $banner_dir = dir('/Users/delphinus/Dropbox/Documents/banner');
my $hostname = 'img.remora.cx';
my %cache;

# put your configuration here
sub load_config {
    my $c = shift;

    my $mode = $c->mode_name || 'development';

    +{
        'DBI' => [
            'dbi:SQLite:dbname=$mode.db',
            '',
            '',
        ],
    }
}

get '/get' => sub { my $c = shift;
    my $p = $c->req->parameters;
    my ($w, $h, $ts) = @$p{qw!w h ts!};
    return $c->res_404 unless $w && $h && $ts;

    my $k = "$w-$h";
    unless ($cache{$k}) {
        my @tmp;
        $banner_dir->recurse(callback => sub{
            my $f = shift;
            $f =~ qr/${w}_$h\.(?:gif|png)$/ or return;
            my $path = $f->parent->file('url.txt')->slurp;
            push @tmp, +{file => $f, path => $path};
        });
        $cache{$k} = \@tmp;
    }

    my @image_cache = @{$cache{$k}};
    return $c->res_404 unless @image_cache;

    my $image = @image_cache[rand @image_cache];
    $c->render('img.tt', +{%$p,
        hostname => $hostname,
        basename => $image->{file}->basename,
        path => $image->{path},
    });
};

get '/img/{name}' => sub { my ($c, $args) = @_;
    my ($name, $w, $h) = $args->{name} =~ /([^_]+)_(\d+)_(\d+)/;
    my $image = file($banner_dir, $name, $args->{name});
    -f $image or return $c->res_404;

    my ($ext) = $image =~ /\.([^.]+)$/;
    my $content = do {
        my $fh = $image->openr;
        $fh->binmode;
        local $/; <$fh>;
    };

    return $c->create_response(
        200,
        [
            'Content-Type' => "image/$ext",
            'Content-Length' => -s $image,
        ],
        $content,
    );
};

# load plugins
__PACKAGE__->load_plugin('Web::CSRFDefender');
# __PACKAGE__->load_plugin('DBI');
# __PACKAGE__->load_plugin('Web::FillInFormLite');
# __PACKAGE__->load_plugin('Web::JSON');

__PACKAGE__->enable_session();

__PACKAGE__->to_app(handle_static => 1);

__DATA__
@@ img.tt
<a href="[% path %]">
    <img width="[% w %]" height="[% h %]" src="http://[% hostname _ uri_for('/img/' _ basename) %]">
</a>

@@ vim:se ft=perl:
