##=================================== Green-blue-deployment ==========================================

##======================================== Requirements ==============================================

* Terraform installed on Jenkins machine
* Correct plugins installed on Jenkins
* GitHub access token for Jenkins
* AWS credentials for Jenkins
* S3 bucket (for terraform.tfstate)

##======================================= Plugins Required ===========================================

* [Workspace Cleanup Plugin](https://wiki.jenkins.io/display/JENKINS/Workspace+Cleanup+Plugin)
* [Credentials Binding Plugin](https://wiki.jenkins.io/display/JENKINS/Credentials+Binding+Plugin)
* [AnsiColor Plugin](https://wiki.jenkins.io/display/JENKINS/AnsiColor+Plugin)
* [GitHub Plugin](https://wiki.jenkins.io/display/JENKINS/GitHub+Plugin)
* [Pipeline Plugin](https://wiki.jenkins.io/display/JENKINS/Pipeline+Plugin)
* [CloudBees AWS Credentials Plugin](https://wiki.jenkins.io/display/JENKINS/CloudBees+AWS+Credentials+Plugin)
