all:
	rebar compile
	rebar escriptize

clean:
	rebar clean
	rm -f recover_couchdb

