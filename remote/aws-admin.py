import sys
import getopt
from boto3 import client

def main(argv):
  try:
    opts, args = getopt.getopt(argv,"v:o:")
  except getopt.GetoptError:
    error_message()
  for opt, arg in opts:
    if opt in ("-v"):
      vpc_name = arg
    elif opt in ("-o"):
      operation = arg
  try:
    task_handler(vpc_name,operation)
  except:
    error_message()

def task_handler(vpc_name,operation):
  try:
    if operation == 'start':
      if client('ecs').update_service(cluster=f'{vpc_name}-ecs-cluster',service=f'{vpc_name}-admin-service',desiredCount=1)['service']['desiredCount'] == 1:
        print("Task started!")
      else:
        exit(1)
    elif operation == 'stop':
      if client('ecs').update_service(cluster=f'{vpc_name}-ecs-cluster',service=f'{vpc_name}-admin-service',desiredCount=0)['service']['desiredCount'] == 0:
        print("Task stopped!")
      else:
        exit(1)
    else:
      exit(1)
  except:
    print("Error! Check the VPC name!")
    exit(1)

def error_message():
  print('Usage: aws-admin.py -v <vpc-name> -o <start|stop>')
  exit(1)
  
if __name__ == "__main__":
   main(sys.argv[1:])