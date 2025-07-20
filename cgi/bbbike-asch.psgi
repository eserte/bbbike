package BBBikeApacheSessionCountedHandler;

use strict;
use warnings;

our $VERSION = '1.00';

use BBBikeApacheSessionCounted;

use Plack::Request;
use Plack::Response;

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);

    # Extract session_id from query string
    my $session_id = $req->query_string;

    my $sess = BBBikeApacheSessionCounted::tie_session($session_id);
    my $res = Plack::Response->new;

    if (!$sess || !(tied %$sess)) {
        warn "Cannot tie session with id $session_id";
        $res->status(404);
        $res->content_type('text/plain');
        $res->body("ERROR: Session id does not exist (anymore)\n");
    } else {
        $res->status(200);
        $res->content_type('application/octet-stream');
        $res->body((tied %$sess)->{serialized});
    }

    return $res->finalize;
};
