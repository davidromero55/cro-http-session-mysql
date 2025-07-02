use Cro::HTTP::Auth;
use Cro::HTTP::Session::MySQL;
use Cro::HTTP::Test;
use DB::MySQL;
use Test;
use Test::Mock;
use JSON::Class;

class MySession does Cro::HTTP::Auth does JSON::Class {
    has $.user-id;
    method set-logged-in-user($!user-id --> Nil) {}
    method is-logged-in(--> Bool) {
        $!user-id.defined
    }
}

# Mock para consultas que devuelven datos (SELECT)
my $fake-select-result = (class {
    has $.json-response is rw = '{ "user-id": null }';
    method value() { self.json-response }
}).new;

# Mock para consultas que modifican datos (INSERT, UPDATE, DELETE)
my $fake-update-result = 1;

my $fake-db = mocked(DB::MySQL, computing => {
    query => -> |c {
        my $sql = c[1] // '';
        if $sql ~~ /SELECT/ {
            $fake-select-result
        }
        else {
            $fake-update-result
        }
    },
    # Add this to handle method calls from the clear method
    execute => -> Mu $self, Str $sql, *@args {
        # Returns a successful result
        True
    },
    prepare => -> Mu $self, Str $sql {
        # Return a prepared statement object that can handle execute calls
        class {
            method execute(*@args) { True }
            method finish() { }
        }.new
    }
});

sub routes() {
    use Cro::HTTP::Router;
    route {
        before Cro::HTTP::Session::MySQL[MySession.new].new:
                db => $fake-db,
                cookie-name => 'myapp';

        get -> MySession $s, 'login' {
            $s.set-logged-in-user(42);
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

    # Verifica que se llamó a query para INSERT y UPDATE, sin importar el orden.
    check-mock $fake-db, *.called('query', with => /INSERT/), *.called('query', with => /UPDATE/);

    test get('/login'),
            status => 204;

    # Actualiza la respuesta para la siguiente prueba de SELECT
    $fake-select-result.json-response = '{ "user-id": 42 }';
    test get('/logged-in'),
            status => 200,
            content-type => 'text/plain',
            body => 'True';

    # Verifica todas las llamadas hasta este punto
    check-mock $fake-db,
            *.called('query', times => 1, with => /INSERT/),
            *.called('query', times => 2, with => /UPDATE/),
            *.called('query', times => 2, with => /SELECT/);
}

done-testing;
