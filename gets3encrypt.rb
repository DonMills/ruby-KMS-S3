########################################
#  Given a filename, it goes to specified bucket, pulls encrypted filename.key down
#  Then uses KMS to decrypt key, and then uses that plaintext to perform decrypting
#  download of encrypted filename.
#  DRM 5/5/16
#  Usage is gets3encrypt.rb {filename} {bucketname} {encryptioncontext}
########################################

require 'aws-sdk'
require 'base64'

###########################
#Below might be needed on windows - if so uncomment
###########################
#Aws.use_bundled_cert!

filename=ARGV[0]
bucket = ARGV[1]
########################################
# The app_context (encryption context) is used to tie the generated key
# with a specific application.  Without both the key and the encryption context,
# KMS will not decrypt anything.  As well the encryption context is logged to Cloudtrail
# so you can track who is decrypting what app's stuff
########################################
app_context = ARGV[2]


def decrypt_key(keyvalue,app_context)
  kms_client = Aws::KMS::Client.new()
  plainkey = kms_client.decrypt(
    ciphertext_blob: keyvalue,
    encryption_context: {
      "Application" => app_context,
      }
  )
    return plainkey.plaintext
end

#########################################
# This whole thing refused to work for hours
# until I base64 encoded the key on upload and
# decoded on download...gave invalidciphertext exception
#########################################
def fetch_key(s3client,filename,bucket)
    keyfile_name= filename+ ".key"
    keyvalue=s3client.get_object(
    key: keyfile_name,
    bucket: bucket
    )
    keyval64 = Base64.decode64(keyvalue.body.read)
    return keyval64
end
##########################################
# reusing the same S3 connection as well below
##########################################
def fetch_file(s3client,plaintext_key,filename,bucket)
  begin
    s3enc = Aws::S3::Encryption::Client.new(encryption_key: plaintext_key,
                                            client: s3client)
    res = s3enc.get_object(bucket: bucket,
                           key: filename,
                           response_target: filename)
  rescue Aws::S3::Errors::ServiceError => e
    puts "upload failed: #{e}"
  end
end

s3client = Aws::S3::Client.new(region: 'us-east-1')
keyval= fetch_key(s3client,filename,bucket)
keyvalue = decrypt_key(keyval,app_context)
fetch_file(s3client,keyvalue,filename,bucket)
