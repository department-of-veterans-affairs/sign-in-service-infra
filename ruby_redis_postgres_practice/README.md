# Sign-in-Service Infrastructure SPIKE

Before running `terraform apply` from the `example` directory do the following:

Create an ECR repo to build / push the image to (the ECS container definition is currently defined as `008577686731.dkr.ecr.us-gov-west-1.amazonaws.com/ihundere-identity:v0.0.1`):

-   `aws ecr create-repository --repository-name <repo_name> --region us-gov-west-1 --tags '[{"Key":"env","Value":"<env_name>"}, {"Key":"owner","Value":"<owner_name>"}]'`
-   `aws ecr get-login-password --region us-gov-west-1 | docker login --username AWS --password-stdin 008577686731.dkr.ecr.us-gov-west-1.amazonaws.com/<repo_name>`
-   `docker buildx build --platform=linux/amd64 . -t 008577686731.dkr.ecr.us-gov-west-1.amazonaws.com/<repo_name>:<tag>`
-   `docker push 008577686731.dkr.ecr.us-gov-west-1.amazonaws.com/<repo_name>:<tag>`

Create a default VPC either from the console or via `aws-cli`:

-   `aws ec2 create-default-vpc`
