# infra---eks

بنية تحتية **Terraform** (VPC، EKS، ECR، إلخ).

- **التطبيق:** [`src---eks`](https://github.com/Ahmedhessn/src---eks)  
- **الـ Kubernetes:** [`k8s---eks`](https://github.com/Ahmedhessn/k8s---eks)  

لا ترفع `terraform.tfstate` أو مفاتيح حساسة؛ استخدم backend بعيد (S3 + قفل) وملف `.gitignore` المرفق.
