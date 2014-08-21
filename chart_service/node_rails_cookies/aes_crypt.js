var crypto = require("crypto");

var AESCrypt = {};

AESCrypt.decrypt = function(key, data) {
	data = new Buffer(data, 'base64').toString('binary');

	var decipher = crypto.createDecipher('aes-256-cbc', key),
		decoded = decipher.update(data, 'binary', 'utf-8');

	decoded += decipher.final('utf-8');
	return decoded;
}

AESCrypt.encrypt = function(key, data) {
	var cipher = crypto.createCipher('aes-256-cbc', key),
		encryptdata = cipher.update(data, 'utf-8', 'binary');

	encryptdata += cipher.final('binary');
	encode_encryptdata = new Buffer(encryptdata, 'binary').toString('base64')
	return encode_encryptdata;
}


// var key = "jakis_tam_klucz";
// var buf = "MAGIcal DATA TO CRYPT";
var key = process.argv[2];
var buf = process.argv[3];


var enc = AESCrypt.encrypt(key, buf);
var dec = AESCrypt.decrypt(key, enc);
console.log(dec);