##! Performs various SSL certificate checks.

@load base/frameworks/notice
@load base/protocols/ssl
@load protocols/ssl/cert-hash

module SSL;

export {
	redef enum Notice::Type += {
        ## Indicates that the subject CN value contains a NUL byte.
		Cert_Contains_NUL_byte,
		## Indicates that the subject CN value is localhost.
		Cert_issued_for_localhost,
		## Indicates that the subject contains default values.
        Cert_with_default_subject_value,
		## Indicates that the connection's SNI value does not match the
		## certificate's subject CN or SNA value.
		Cert_SNI_Mismatch
	};
}

function report_sni_mismatch(c: connection, cn: string, sni: string)
    {
    local msg = fmt("SNI value does not match certificate subject CN or SAN");
    NOTICE([$note=Cert_SNI_Mismatch, $msg=msg, $sub=c$ssl$subject, $conn=c,
		    $identifier=cat(c$id$resp_h, c$id$resp_p, c$ssl$cert_hash)]);
    }

event x509_certificate(c: connection, is_orig: bool, cert: X509, 
    chain_idx: count, chain_len: count, der_cert: string) &priority=3
	{
	if ( ! c$ssl?$subject )
		return;

    local subject = split_dn(c$ssl$subject);
    local cn = subject["CN"];

	if ( /\x00/ in cn )
	    {
		local msg = fmt("SSL certificate with NUL byte in subject CN (%s)", cn);
		NOTICE([$note=Cert_Contains_NUL_byte, $msg=msg,
		        $sub=c$ssl$subject, $conn=c,
		        $identifier=cat(c$id$resp_h, c$id$resp_p, c$ssl$cert_hash)]);
		}

    # Check for abnormal subject values.
    if ( /localhost/ in cn && Site::is_local_addr(c$id$resp_h) )
		NOTICE([$note=Cert_issued_for_localhost,
		        $msg="SSL certificate issued for localhost",
		        $sub=c$ssl$subject, $conn=c,
		        $identifier=cat(c$id$resp_h, c$id$resp_p, c$ssl$cert_hash)]);

    if ( (/Internet Widgits Pty Ltd/ in subject["O"] ||
          /Some-State/ in subject["ST"]) && Site::is_local_addr(c$id$resp_h) )
		NOTICE([$note=Cert_with_default_subject_value,
		        $msg="SSL certificate with default subject value",
		        $sub=c$ssl$subject, $conn=c,
		        $identifier=cat(c$id$resp_h, c$id$resp_p, c$ssl$cert_hash)]);

    # Check for wildcards in SNI.
    # TODO: we also need to compare the SNI value against the certificate's
    # Server Alternate Names field, Otherwise we get too many false positivies.
    if ( ! c$ssl?$server_name )
        return;

    local sni = c$ssl$server_name;

    if ( /^\*\./ in cn )
        {
        local suffix = sub(cn, /^\*\./, "");
        if ( strstr(sni, suffix) == 0 )
            report_sni_mismatch(c, cn, sni);
        }
    else if ( cn != sni )
            report_sni_mismatch(c, cn, sni);
	}
