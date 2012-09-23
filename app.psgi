use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Amon2::Lite;
use Cache::Memcached::Fast;
use JSON;
use Path::Class;
use Log::Minimal;
$Log::Minimal::AUTODUMP = 1;

our $VERSION = '0.01';

my $banner_dir = dir('/Users/delphinus/Dropbox/Documents/banner');
my $hostname = 'img.remora.cx';
my $memd = Cache::Memcached::Fast->new({
    servers => ['127.0.0.1:11211'],
    namespace => 'bannerserver:',
    utf8 => 1,
});

get '/get' => sub { my $c = shift;
    my $p = $c->req->parameters;
    my ($w, $h, $ts) = @$p{qw!w h ts!};
    return $c->res_404 unless $w && $h && $ts;

    my $key = "$w-$h";
    my $cache = $memd->get($key);

    unless ($cache) {
        my @tmp;
        $banner_dir->recurse(callback => sub{
            my $f = shift;
            $f =~ qr/${w}_$h\.(?:gif|png)$/ or return;
            my $path = $f->parent->file('url.txt')->slurp;
            push @tmp, +{file => $f, path => $path};
        });
        $memd->set($key => \@tmp);
        $cache = \@tmp;
    }

    my @image_cache = @$cache;
    return $c->res_404 unless @image_cache;

    my $image = @image_cache[rand @image_cache];
    my $html = $c->create_view->render('img.tt', +{%$p,
        hostname => $hostname,
        basename => $image->{file}->basename,
        path => $image->{path},
    });
    my $js = to_json(+{content => $html});

    my $content_type;
    if (defined $p->{callback}) {
        $content_type = 'text/javascript';
        $js = "$p->{callback}($js);";
    } else {
        $content_type = 'application/json';
    }

    return $c->create_response(
        200,
        [
            'Content-Type' => $content_type,
            'Content-Length' => length $js,
        ],
        $js,
    );
};

get '/img/{name}' => sub { my ($c, $args) = @_;
    my ($name, $w, $h) = $args->{name} =~ /([^_]+)_(\d+)_(\d+)/;
    my $image = file($banner_dir, $name, $args->{name});
    my ($ext) = $image =~ /\.([^.]+)$/;
    my $key = $image->absolute->stringify;
    my $content = $memd->get($key);

    unless ($content) {
        -f $image or return $c->res_404;
        $content = do {
            my $fh = $image->openr;
            $fh->binmode;
            local $/; <$fh>;
        };
        $memd->set($key => $content);
    }

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
__PACKAGE__->load_plugin('Web::JSON');

__PACKAGE__->enable_session();

__PACKAGE__->to_app(handle_static => 1);

__DATA__
@@ img.tt
<a target="_blank" href="[% path %]">
    <img width="[% w %]" height="[% h %]" src="http://[% hostname _ uri_for('/img/' _ basename) %]">
</a>

@@ vim:se ft=perl:
