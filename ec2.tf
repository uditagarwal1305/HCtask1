provider "aws" {
  region  = "ap-south-1"
  profile="udit"
}

// Here a private key is generated which contain public_key_openssh for future use 

resource "tls_private_key" "task1privatekey" {
  algorithm   = "RSA"
}
resource "aws_key_pair" "task1key" {
  depends_on = [
    tls_private_key.task1privatekey,
  ]
  key_name   = "task1key"
  public_key =  tls_private_key.task1privatekey.public_key_openssh
}


// Now we create Security group

resource "aws_security_group" "Mytask1SG"{ 
    name = "ServiceSG" 
    vpc_id = "vpc-eaced182" 
     
    ingress{ 
           from_port=80 
           to_port = 80 
           protocol="tcp" 
           cidr_blocks=["0.0.0.0/0"] 
     } 
  
    ingress{ 
             from_port=22 
           to_port = 22 
           protocol="tcp" 
           cidr_blocks=["0.0.0.0/0"] 
      }  
    egress{ 
           from_port=0
           to_port = 0 
           protocol="-1" 
           cidr_blocks=["0.0.0.0/0"] 
        }
    tags = {
           Name = "allow_http_ssh"
     }
         } 


// Now we have to Launch instance

resource "aws_instance" "Mytask1in" { 
   ami            = "ami-0447a12f28fddb066" 
   instance_type  = "t2.micro" 
   key_name       = "task1key"
   security_groups = ["${aws_security_group.Mytask1SG.name}"] 
    
  
    connection { 
     type     = "ssh" 
     user     = "ec2-user" 
     private_key =  tls_private_key.task1privatekey.private_key_pem
     host     = aws_instance.Mytask1in.public_ip 
   } 
     provisioner "remote-exec" { 
      inline = [ 
        "sudo yum install httpd  php git -y", 
        "sudo systemctl restart httpd", 
        "sudo systemctl enable httpd", 
     ] 
   } 
  
   tags = { 
     Name = "Web_OS" 
    } 
 } 

//Now we create persistent hard disk or volume

resource "aws_ebs_volume" "ebs" {
   depends_on = [
    aws_instance.Mytask1in,
  ]
   availability_zone = aws_instance.Mytask1in.availability_zone 
   size              = 1 
  
   tags = { 
     Name = "myebs" 
   } 
 } 


//Now we attach volume

resource "aws_volume_attachment" "ebs_att" { 
   depends_on = [
    aws_instance.Mytask1in, aws_ebs_volume.ebs,
  ]
   device_name = "/dev/sdh" 
   volume_id   = aws_ebs_volume.ebs.id 
   instance_id = aws_instance.Mytask1in.id 
   force_detach= true 
 } 



//

resource "null_resource" "connection"  {

 depends_on = [
    aws_s3_bucket_object.Mytask1bu,aws_cloudfront_origin_access_identity.origin_access_identity,
		aws_cloudfront_distribution.Mytask1cd,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"

    private_key = tls_private_key.task1privatekey.private_key_pem

    host     = aws_instance.Mytask1in.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/uditagarwal1305/cloudfront.git /var/www/html/",
      "sudo su << EOF",
            "echo \"${aws_cloudfront_distribution.Mytask1cd.domain_name}\" >> /var/www/html/myimg.txt",
            "EOF",
      "sudo systemctl stop httpd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }
}


resource "aws_s3_bucket" "Mytask1s3bu" {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]

  bucket = "amazon-linux-os-bucket"
  acl    = "public-read"
  force_destroy = true
  tags = {
	Name = "Mytask1bu"
  }
}

   locals {
	s3_origin_id = "myorigin"
   }


resource "aws_s3_bucket_object" "Mytask1bu" {

depends_on = [
    aws_s3_bucket.Mytask1s3bu,
  ]

  bucket = aws_s3_bucket.Mytask1s3bu.id
  key    = "image.png"
  source = "C:/Users/ok/Desktop/tera/mytest/image.png"
  etag   = "C:/Users/ok/Desktop/tera/mytest/image.png"
  force_destroy = true
  acl    = "public-read"
  
}


resource "aws_s3_bucket_public_access_block" "make_item_public" {
  bucket = aws_s3_bucket.Mytask1s3bu.id

  block_public_acls   = false
  block_public_policy = false
}


resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "origin access identity"
}


resource "aws_cloudfront_distribution" "Mytask1cd" {
  
depends_on = [
    aws_s3_bucket_object.Mytask1bu,
  ]


  origin {
    domain_name = aws_s3_bucket.Mytask1s3bu.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
 
    s3_origin_config {
        origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }	

	enabled             = true
	is_ipv6_enabled     = true
  	comment             = "my cloudfront s3 distribution"
  	default_root_object = "index.php"


  default_cache_behavior {

    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]

    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }


   viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  
   restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true  
  }
}






output "amazon_linux_os_ip_address" {
	value = aws_instance.Mytask1in.public_ip
}

output "amazon_linux_os_availability_zone" {
	value = aws_instance.Mytask1in.availability_zone
}
