var crypto = require('crypto');

function cookieDecoder(options) {
	var generated_secret = crypto.pbkdf2Sync(options.secret_key_base, 
											 options.encrypted_cookie_salt, 
											 options.iterations, 
											 options.keylen/2);
	var generated_signed_secret = crypto.pbkdf2Sync(options.secret_key_base,
													options.encrypted_signed_cookie_salt,
													options.iterations,
													options.keylen);

	return function(cookie) {
		var cookie_parts = unescape(cookie).split('--');
		var parts = new Buffer(cookie_parts[0], 'base64').toString().split("--");
		var parts = parts.map(function(data) {
			return new Buffer(data, 'base64');
		});

		var hmac = crypto.createHmac('sha1', generated_signed_secret);
		hmac.update(cookie_parts[0]);
		var digest = hmac.digest("hex");

		if(digest != cookie_parts[1]) {
			return;
		}

		var decipher = crypto.createDecipheriv(options.cipherName, generated_secret, parts[1]);
		var decipher_update = new Buffer(decipher.update(parts[0])).toString('ascii');
		decipher_update += decipher.final('ascii');
		
		return decipher_update;
	}
}

module.exports = cookieDecoder;