use Cro::HTTP::Auth;
use Cro::HTTP::Session::MySQL;
use Cro::HTTP::Test;
use DB::MySQL;
use Test;
use Test::Mock;
use JSON::Class;

class MySession does Cro::HTTP::Auth does JSON::Class {
    has $.user-id is rw = 0;
    method set-logged-in-user($id --> Nil) { 
        $!user-id = $id 
    }
    method is-logged-in(--> Bool) { $!user-id > 0 }
}

my $current-fake-json = '{}';
my $fake-update-result = 1;

my $fake-db = mocked(DB::MySQL, overriding => {
    query => -> *@args {
        my $sql = @args[0];
        if $sql ~~ /INSERT/ {
            $fake-update-result  # No 'return' keyword - just make it the last expression
        } elsif $sql ~~ /UPDATE/ {
            $current-fake-json = @args[1];  # Update the current fake JSON
            $fake-update-result  # Return numeric value
        } elsif $sql ~~ /DELETE/ {
            $fake-update-result  # Return numeric value
        } else {
            # Return an object that supports .value and .CALL-ME
            class {
                method value() {
                    $current-fake-json
                }
            }.new
        }
    }
});

sub routes() {
    use Cro::HTTP::Router;
    route {
       before Cro::HTTP::Session::MySQL[MySession].new:
               db => $fake-db,
               cookie-name => 'myapp';

        get -> MySession $s, 'login' {
            $s.set-logged-in-user(42);
            content 'text/plain', 'False';
        }

        get -> MySession $s, 'logged-in' {
            content 'text/plain', $s.is-logged-in.Str;
        }
    }
}

test-service routes(), :http<1.1>, :cookie-jar, {
    test get('/logged-in'),
            status => 200,
            content-type => 'text/plain',
            body => 'False';

    check-mock $fake-db,
            *.called('query', times => 1, with => :($ where /INSERT/, *@)),
            *.called('query', times => 1, with => :($ where /UPDATE/, *@));

    test get('/login'),
            status => 200;

    check-mock $fake-db,
             *.called('query', times => 1, with => :($ where /SELECT/, *@)),
             *.called('query', times => 2, with => :($ where /UPDATE/, *@));

    test get('/logged-in'),
            status => 200,
            content-type => 'text/plain',
            body => 'True';

    check-mock $fake-db,
            *.called('query', times => 3, with => :($ where /UPDATE/, *@));
}

done-testing;