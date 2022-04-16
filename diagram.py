from diagrams import Diagram, Cluster
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.network import ELB, InternetGateway, NATGateway
import os
import argparse
from dotenv import dotenv_values, load_dotenv

parser = argparse.ArgumentParser()
parser.add_argument("env", default="some_var")
args = parser.parse_args()

config = load_dotenv('vars/'+args.env+'/main.tfvars')

region = os.environ['region']
vpc_name = os.environ['vpc_name']
vpc_cidr = os.environ['vpc_cidr']
public_subnets = (os.environ['vpc_public_subnets']).replace("[","").replace("]","").split(", ")
private_subnets = os.environ['vpc_private_subnets'].replace("[","").replace("]","").split(", ")
instance_type = os.environ['ec2_instance_type']


with Diagram("Terraform example" , show=False, direction="TB"):
    with Cluster("VPC \n"+"Region: "+region+" \n"+"Network: " +vpc_cidr):
        with Cluster("Security Group\n ingress 0.0.0.0/0 tcp-port 22\ningress 0.0.0.0/0 tcp-port 80"):
            with Cluster("Private Subnets\n "+private_subnets[0]+" az-a"+"\n"+private_subnets[1]+" az-b"+"\n"+private_subnets[2]+" az-c"):
                [EC2("private-ec2-two"+"\n"+instance_type),
                EC2("private-ec2-one"+"\n"+instance_type)]
                NATGateway("PrivateNGW")
            with Cluster("Public Subnets\n "+public_subnets[0]+" az-a"+"\n"+public_subnets[1]+" az-b"+"\n"+public_subnets[2]+" az-c"):
                EC2("public_ec2"+"\n"+instance_type)
                InternetGateway("IGW")