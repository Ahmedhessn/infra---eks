# infra---eks

Terraform: **كلاستر EKS واحد (موحّد)** عبر AZين في `live/unified`، أو نموذج قديم منفصل لـ dev/staging؛ **prod** اختياريًا self-managed في `live/prod/k8s`.

- التطبيق: [src---eks](https://github.com/Ahmedhessn/src---eks)
- الـ Kubernetes: [k8s---eks](https://github.com/Ahmedhessn/k8s---eks)

## قبل تشغيل الـ Pipeline (تحقق سريع)

| # | المطلوب | أين |
|---|---------|-----|
| 1 | حساب AWS صحيح + CLI/ OIDC | `aws sts get-caller-identity` |
| 2 | **Root bucket + DynamoDB** (لـ bootstrap state) | مرة واحدة في AWS |
| 3 | `TF_ROOT_STATE_BUCKET` ، `TF_ROOT_STATE_LOCK_TABLE` | GitHub → repo **Secrets** |
| 4 | `AWS_TERRAFORM_APPLY_ROLE_ARN` | Secrets |
| 5 | `AWS_TERRAFORM_PLAN_ROLE_ARN` | Secrets (لـ PR plan / تشغيل يدوي لـ **Terraform PR plan**) |
| 6 | **Environments:** `unified` ، `dev` ، … و **`production`** للـ prod | GitHub → **Environments** |
| 7 | (اختياري) `K8S_REPO_DISPATCH_TOKEN` إن فعّلت notify على **k8s---eks** | Secrets |
| 8 | (اختياري) **Variables:** `AWS_REGION` ، `TF_PROJECT_PREFIX` | GitHub → **Variables** |

**ترتيب التشغيل:** `Terraform bootstrap` (**unified**) → `Terraform apply` (**unified**).  
**Plan بدون PR:** Actions → **Terraform PR plan** → **Run workflow** (يظهر الملخص في الصفحة + artifacts).

## البيئات (multi-env)

| المسار | الوصف |
|--------|--------|
| **`live/unified/bootstrap` + `live/unified/k8s`** | **EKS واحد** + VPC على **AZين** + ECR مشتركة. dev/staging/prod = **namespaces** داخل نفس الكلاستر. |
| `live/dev/...` ، `live/staging/...` | نموذج قديم (EKS منفصل لكل بيئة). |
| `live/prod/...` | **self-managed** على EC2 (ليس EKS) في الكود الحالي. |

الـ state: `<project>-<env>-tf-state`. للموحّد: env = **`unified`**. اسم الكلاستر: **`<project>-eks`** (مثال: `k8s-emad-128768042813-eks`).

## البناء من Pipeline (ترتيب التنفيذ)

1. **مرة واحدة في AWS:** أنشئ **bucket + DynamoDB** لحفظ **state الخاص بـ bootstrap** (مش نفس bucket الـ env — ده “root” للـ CI فقط).  
   مثال أسماء (غيّرها لو الـ bucket مش متاح عالميًا):  
   `k8s-emad-128768042813-tf-root` + `k8s-emad-128768042813-tf-root-locks`  
   انسخ القيم من `live/dev/bootstrap/backend.hcl.example`.

2. في **GitHub → infra---eks → Secrets** أضف:
   - `TF_ROOT_STATE_BUCKET` — اسم الـ root bucket  
   - `TF_ROOT_STATE_LOCK_TABLE` — اسم جدول الـ locks  
   - `AWS_TERRAFORM_APPLY_ROLE_ARN` — دور OIDC (نفس المستخدم لـ apply)

3. **Actions → Terraform bootstrap → Run workflow:** اختر **`unified`** (أو `dev` لو ما زلت على النموذج القديم)، ثم **apply** عند الجاهزية.

4. انسخ من **output** إلى `live/unified/k8s/backend.hcl` أو استخدم **Terraform apply** من GitHub (يولّد `backend.ci.hcl` تلقائيًا).

5. **Actions → Terraform apply:** اختر **`unified`** و **apply** لبناء **VPC (2 AZ) + EKS واحد + ECR**.

## GitHub Actions

### 1) `terraform plan` — PR أو يدوي

Workflow: `.github/workflows/terraform-pr.yml`

- **Pull Request:** يعلّق على الـ PR (sticky) لكل stack: `unified`، `dev`، `staging`، `prod`.
- **Run workflow:** نفس الـ plans بدون PR؛ الملخص في **Summary** للـ run + ملفات **artifacts**.

**إعداد:**

1. **OIDC:** دور IAM يثق في `token.actions.githubusercontent.com` ويحدد repo هذا فقط.
2. **Secret:** `AWS_TERRAFORM_PLAN_ROLE_ARN` — ARN الدور (صلاحيات قراءة/كتابة state + تنفيذ plan على الموارد).
3. **Variable (اختياري):** `TF_PROJECT_PREFIX` — افتراضيًا `k8s-emad-128768042813` (أحرف صغيرة؛ متطلب S3).
4. **Variable (اختياري):** `AWS_REGION` — افتراضيًا `us-east-1`.

**ملاحظة:** الـ plan على PRs من **نفس المستودع** فقط (لأسباب أمنية).

### 2) يدوي: plan / apply + إشعار مستودع الـ k8s

Workflow: `.github/workflows/terraform-apply.yml`

- **Secrets:** `AWS_TERRAFORM_APPLY_ROLE_ARN`، وإن فعّلت «notify k8s»: `K8S_REPO_DISPATCH_TOKEN` (PAT بصلاحية `repo` على `k8s---eks`).
- **Variable (اختياري):** `K8S_MANIFESTS_REPO` — افتراضيًا `Ahmedhessn/k8s---eks`.
- **GitHub Environments:** أنشئ `dev` و `staging` و **`production`**؛ ضع **مطلوب موافقين** على `production` قبل الـ apply.

خيار **Notify k8s** يُرسل `repository_dispatch` لـ **EKS فقط** (يُتخطى لـ `prod` لأن الـ stack الحالي ليس EKS).

## الربط مع نشر EKS

في [k8s---eks](https://github.com/Ahmedhessn/k8s---eks): workflow `deploy-eks.yml`

- يستقبل الحدث `eks-infra-applied` أو يدويًا يختار `dev` / `staging`.
- **Secret:** `AWS_EKS_DEPLOY_ROLE_ARN` — دور يستطيع `eks:DescribeCluster` و `eks:AccessKubernetesApi` (أو سياسة مكافئة لـ `kubectl`).

اسم الكلاستر المتوقع: `<TF_PROJECT_PREFIX>-<env>-eks`.

لا ترفع `terraform.tfstate` أو مفاتيح؛ راجع `.gitignore`.
