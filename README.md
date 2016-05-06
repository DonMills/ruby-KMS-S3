# ruby-KMS-S3
A set of utils to encrypt and upload/download files from S3 using KMS to generate keys

puts3encrypt.rb allows you to:

1. generate a file-specific encryption key using KMS with a specific encryption context
2. upload the encrypted key to s3
3. encrypt a file with the key and upload that to s3 as well

gets3encrypt.rb allows you to:

1. fetch the encrypted key from s3
2. decrypt the key using KMS
3. download and decrypt the encrypted file.

It's magic!

Usage:

`puts3encrypt.rb {filename} {bucketname} {encryptioncontext}`

`gets3encrypt.rb {filename} {bucketname} {encryptioncontext}`

The encryption context must match or you will receive an invalidciphertext exception.  This allows you to not only use some measure of two factor authentication (the encrypted key you have and the context you know), but also allows you to tie encryption keys to specific usages.  The encryption context is also logged into cloudtrail whenever you use the key generated with it....

