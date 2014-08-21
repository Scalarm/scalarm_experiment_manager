var crypto = require('crypto');
console.log(crypto)

// constant time comparison
function compare(a, b) {
  if ( a.length !== b.length ) {
    return false;
  }

  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }

  return 0 === result;
}

decrypt = function(options) {
  var secret = crypto.pbkdf2Sync(options.base, options.salt, options.iterations, options.keylen / 2)
    , signed_secret = crypto.pbkdf2Sync(options.base, options.signed_salt, options.iterations, options.keylen)
    ;

  return function(cookie, cipherName) {

    var signed_parts = cookie.split('--')
      , hmac = crypto.createHmac('sha1', signed_secret)
      , digest
      ;

    hmac.update(signed_parts[0]);
    digest = hmac.digest('hex');

    if ( !compare(signed_parts[1], digest) ) return console.log('not valid');

    var message = (new Buffer(signed_parts[0], 'base64').toString())
      , parts = message.split('--').map(function(part) {
          return new Buffer(part, 'base64');
        })
      ;

    var cipher = crypto.createDecipheriv(cipherName, secret, parts[1])
      , part = new Buffer(cipher.update(parts[0])).toString('utf8')
      , final = cipher.final('utf8')
      ;

    return [part, final].join('');
  }
};

var options = {}
options.base = 'd132fd22bc612e157d722e980c4b0525b938f225f9f7f66ea';
options.salt = "encrypted cookie"
options.signed_salt = "signed encrypted cookie"
options.iterations = 1000
options.keylen = 64

cookie = "M0o4WEczUEM1UndWZXU5aXVSemlHTUNTT002dzhwY0hUL2ZOdjh4NHpHUkdKWWN3R2RoRU1oc1R0Rkp0NFVCNTJOMzdPc3JnN0RYVW1tZkxsQzRGYVNHV2hndFVSL1BDeWwxV2RTMStBK0w1NUNob1FJUDE2d3VCR1J2c1ZGS2Rabko5cnJFcTRqeFhJcEtZMDBmVCtPVFVLQkJ3L09zNUpZVmNoNHIwd0hHSVA3b1FwWUNLZGxTZDduS2JFVlprSmx4Q1Bsek9QUXpITU11Z0IzaWpTSmVZTFMzRkpoOVExYUZWaFhCR3MzZDdMbkZFdnlKQW5ucGwwdSs4YisrV1lDRmtrVU9yRFl5ODliSWpmVWljOTM2SHA5djRWakVxY0dYT2VNZDRjTm1JdFFhNVY5aUY5R25aVDFuWE41bEVvZ2IrTkNOU1owU1ZZbDRGT2Fyc3prZjh0bFJEU2NWRjlKZFNJOHlRcExNPS0tams3eFZEL0ZmODd5RXhOQ1VwNjlJdz09--eb474ab66d97eab3f79581699b93b71e8b8322e9"
cipherName = "aes-256-cbc"

fun = decrypt(options)
console.log(new Buffer(fun(cookie,cipherName)).toString('base64'));