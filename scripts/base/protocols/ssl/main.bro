
module SSL;

export {
	redef enum Log::ID += { SSL };

	redef enum Notice::Type += {
		Self_Signed_Cert
	};

	type Info: record {
		ts:               time             &log;
		uid:              string           &log;
		id:               conn_id          &log;
		version:          string           &log &optional;
		cipher:           string           &log &optional;
		server_name:      string           &log &optional;
		subject:          string           &log &optional;
		not_valid_before: time             &log &optional;
		not_valid_after:  time             &log &optional;
		
		cert:             string           &optional;
		cert_chain:       vector of string &optional;
	};
	
	## This is where the default root CA bundle is defined.  By loading the
	## mozilla-ca-list.bro script it will be set to Mozilla's root CA list.
	const root_certs: table[string] of string = {} &redef;
	
	global log_ssl: event(rec: Info);
	
	const ports = {
		443/tcp, 563/tcp, 585/tcp, 614/tcp, 636/tcp,
		989/tcp, 990/tcp, 992/tcp, 993/tcp, 995/tcp, 5223/tcp
	} &redef;
}

redef record connection += {
	ssl: Info &optional;
};

event bro_init() &priority=5
	{
	Log::create_stream(SSL, [$columns=Info, $ev=log_ssl]);
	}

redef capture_filters += {
	["ssl"] = "tcp port 443",
	["nntps"] = "tcp port 563",
	["imap4-ssl"] = "tcp port 585",
	["sshell"] = "tcp port 614",
	["ldaps"] = "tcp port 636",
	["ftps-data"] = "tcp port 989",
	["ftps"] = "tcp port 990",
	["telnets"] = "tcp port 992",
	["imaps"] = "tcp port 993",
	["ircs"] = "tcp port 994",
	["pop3s"] = "tcp port 995",
	["xmpps"] = "tcp port 5223",
};

redef dpd_config += {
	[[ANALYZER_SSL]] = [$ports = ports]
};

function set_session(c: connection)
	{
	if ( ! c?$ssl )
		c$ssl = [$ts=network_time(), $uid=c$uid, $id=c$id, $cert_chain=vector()];
	}

event ssl_client_hello(c: connection, version: count, possible_ts: time, session_id: string, ciphers: count_set) &priority=5
	{
	set_session(c);
	}
	
event ssl_server_hello(c: connection, version: count, possible_ts: time, session_id: string, cipher: count, comp_method: count) &priority=5
	{
	set_session(c);
	
	c$ssl$version = version_strings[version];
	c$ssl$cipher = cipher_desc[cipher];
	}

event x509_certificate(c: connection, cert: X509, is_server: bool, chain_idx: count, chain_len: count, der_cert: string) &priority=5
	{
	set_session(c);
	
	if ( chain_idx == 0 )
		{
		# Save the primary cert.
		c$ssl$cert = der_cert;
		
		# Also save other certificate information about the primary cert.
		c$ssl$subject = cert$subject;
		c$ssl$not_valid_before = cert$not_valid_before;
		c$ssl$not_valid_after = cert$not_valid_after;
		}
	else
		{
		# Otherwise, add it to the cert validation chain.
		c$ssl$cert_chain[|c$ssl$cert_chain|] = der_cert;
		}
	}
	
event ssl_extension(c: connection, code: count, val: string) &priority=5
	{
	set_session(c);
	
	if ( extensions[code] == "server_name" )
		c$ssl$server_name = sub_bytes(val, 6, |val|);
	}
	
event ssl_established(c: connection) &priority=-5
	{
	set_session(c);
	
	Log::write(SSL, c$ssl);
	}
	