########################################
#  Generates a new key from KMS, uses plaintext to encrypt S3 transfer
#  Then uploads encrypted key as well as filename.key
#  DRM 5/5/16
#  Usage is puts3encrypt.rb {filename} {bucketname} {encryptioncontext}
########################################

require 'aws-sdk'
require 'base64'

########################################
#Below might be needed on Windows, if so uncomment
########################################
#Aws.use_bundled_cert!

filename=ARGV[0]
uploadfile = File.new(filename)
bucket = ARGV[1]

########################################
# The app_context (encryption context) is used to tie the generated key
# with a specific application.  Without both the key and the encryption context,
# KMS will not decrypt anything.  As well the encryption context is logged to Cloudtrail
# so you can track who is decrypting what app's stuff
########################################
app_context= ARGV[2]

########################################
# This was to write the encrypted key locally, but I figured out how to do it all
# in memory.  You could still uncomment and use if you wanted local encrypted key copy
# Plaintext key never touches filesystem.
########################################
#def write_enc_key(keyblob,name)
#  keyname = name + ".key"
#  keyfile = File.new(keyname, "w")
#  keyfile.write(keyblob)
#  keyfile.close
#  return keyname
#end

########################################
# Put your KMS master key id under key_id
########################################

def fetch_new_key(app_context)
  kms_client = Aws::KMS::Client.new()
  genkey = kms_client.generate_data_key({
    key_id: "putyourmasterkeyidhere",
    key_spec: "AES_256",
    encryption_context: {
      "Application" => app_context,
      }
    })
    return genkey.ciphertext_blob, genkey.plaintext
end

#########################################
# This whole thing refused to work for hours
# until I base64 encoded the key on upload and
# decoded on download...gave invalidciphertext exception
#########################################

def upload_key(s3client,newkeyblob,filename,bucket)
    keyfile_name= filename+ ".key"
    newkeyblob64 = Base64.encode64(newkeyblob)
  s3client.put_object({
    body: newkeyblob64,
    key: keyfile_name,
    bucket: bucket
    })
end

#########################################
# Reusing the same s3 connection as well below
#########################################
def upload_file(s3client,plaintext_key,filename,bucket)
  begin
    filebody = File.new(filename)
    s3enc = Aws::S3::Encryption::Client.new(encryption_key: plaintext_key,
                                            client: s3client)
    res = s3enc.put_object(bucket: bucket,
                           key: filename,
                           body: filebody)
  rescue Aws::S3::Errors::ServiceError => e
    puts "upload failed: #{e}"
  end
end

newkeyblob, newkeyplain = fetch_new_key(app_context)
#write_enc_key(newkeyblob,filename)
s3client = Aws::S3::Client.new(region: 'us-east-1')
upload_key(s3client,newkeyblob,filename,bucket)
upload_file(s3client,newkeyplain,filename,bucket)
