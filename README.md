# infra---eks

Terraform (VPC، EKS لـ dev/staging، ECR، …) + **prod** على شكل self-managed K8s في `live/prod/k8s`.

- التطبيق: [src---eks](https://github.com/Ahmedhessn/src---eks)
- الـ Kubernetes: [k8s---eks](https://github.com/Ahmedhessn/k8s---eks)

## البيئات (multi-env)

| المسار | الوصف |
|--------|--------|
| `live/dev/bootstrap` + `live/dev/k8s` | Dev + **EKS** |
| `live/staging/bootstrap` + `live/staging/k8s` | Staging + **EKS** (مرة واحدة: طبّق bootstrap ثم k8s) |
| `live/prod/bootstrap` + `live/prod/k8s` | Prod (نموذج **self-managed** — ليس نفس شكل EKS) |

أسماء الـ state تتبع الوحدة `modules/remote_state`:  
`<project>-<env>-tf-state` و `<project>-<env>-tf-locks`.

## GitHub Actions

### 1) PR → تعليق فيه `terraform plan` (لكل بيئة)

Workflow: `.github/workflows/terraform-pr.yml`

- يولّد `backend.ci.hcl` تلقائياً من **نفس تسمية الـ bucket** أعلاه.
- يضيف/يحدّث **تعليق لزق على الـ PR** لكل من `dev` و `staging` و `prod` (sticky header لكل بيئة).

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
