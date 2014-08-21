module.exports.options = {
	secret_key_base: 'f19179f2adf3d52d46a23e286da942e5573afba02ea4b43bc0fd64996d538cb05b4ddf2867b3df1a2ac3f55060fceec3e18a6468ceaef6c99f782eaa851d9868', //blog
	encrypted_cookie_salt: "encrypted cookie",
	encrypted_signed_cookie_salt: "signed encrypted cookie",
	iterations: 1000,
	keylen: 64,
	cipherName: 'aes-256-cbc'
};