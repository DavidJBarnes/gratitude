#!/bin/bash
set -euo pipefail

# =============================================================================
# Gratitude App — AWS Infrastructure Setup
# =============================================================================
# Creates ECR repos, IAM OIDC role, and sets GitHub secrets.
# Requires: aws CLI authenticated, gh CLI authenticated.
#
# Usage:
#   aws login   # or however you authenticate
#   ./scripts/setup-aws.sh
# =============================================================================

AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="791342033319"
GITHUB_ORG="DavidJBarnes"
GITHUB_REPO="gratitude"
EC2_INSTANCE_ID="i-07eab9fcba8e4457a"
PROJECT_NAME="gratitude"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Gratitude App — AWS Setup ===${NC}"

# --- 1. ECR Repositories ---
echo -e "\n${YELLOW}[1/4] Creating ECR repositories...${NC}"

for repo in gratitude-api gratitude-nginx; do
  if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "  ECR repo '$repo' already exists"
  else
    aws ecr create-repository \
      --repository-name "$repo" \
      --region "$AWS_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --tags Key=Project,Value=gratitude \
      --output text --query 'repository.repositoryUri'
    echo -e "  ${GREEN}Created ECR repo '$repo'${NC}"
  fi
done

# --- 2. OIDC Provider (shared, may already exist) ---
echo -e "\n${YELLOW}[2/4] Ensuring OIDC provider exists...${NC}"

OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "  OIDC provider already exists"
else
  THUMBPRINT=$(openssl s_client -connect token.actions.githubusercontent.com:443 -servername token.actions.githubusercontent.com </dev/null 2>/dev/null | openssl x509 -fingerprint -noout 2>/dev/null | cut -d= -f2 | tr -d : | tr '[:upper:]' '[:lower:]')
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list "$THUMBPRINT"
  echo -e "  ${GREEN}Created OIDC provider${NC}"
fi

# --- 3. IAM Role for GitHub Actions ---
echo -e "\n${YELLOW}[3/4] Creating IAM role for GitHub Actions...${NC}"

ROLE_NAME="GitHubActions-${PROJECT_NAME}-CICD-Role"
POLICY_NAME="GitHubActions-${PROJECT_NAME}-CICD-Policy"

# Trust policy
TRUST_POLICY=$(cat <<TRUST
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
TRUST
)

# Permissions policy
PERMISSIONS_POLICY=$(cat <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": [
        "arn:aws:ecr:${AWS_REGION}:${AWS_ACCOUNT_ID}:repository/gratitude-api",
        "arn:aws:ecr:${AWS_REGION}:${AWS_ACCOUNT_ID}:repository/gratitude-nginx"
      ]
    },
    {
      "Sid": "SSMDeploy",
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation"
      ],
      "Resource": [
        "arn:aws:ssm:${AWS_REGION}::document/AWS-RunShellScript",
        "arn:aws:ec2:${AWS_REGION}:${AWS_ACCOUNT_ID}:instance/${EC2_INSTANCE_ID}"
      ]
    }
  ]
}
POLICY
)

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "  Role '$ROLE_NAME' already exists, updating trust policy..."
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$TRUST_POLICY"
else
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --tags Key=Project,Value=gratitude \
    --output text --query 'Role.Arn'
  echo -e "  ${GREEN}Created role '$ROLE_NAME'${NC}"
fi

# Attach inline policy
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "$PERMISSIONS_POLICY"
echo "  Policy attached"

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

# --- 4. EC2 Instance Profile (for ECR pull + SSM agent) ---
echo -e "\n${YELLOW}[4/6] Creating EC2 instance profile...${NC}"

EC2_ROLE_NAME="EC2-${PROJECT_NAME}-Role"
EC2_PROFILE_NAME="EC2-${PROJECT_NAME}-Profile"

EC2_TRUST_POLICY=$(cat <<EC2TRUST
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EC2TRUST
)

EC2_POLICY=$(cat <<EC2POL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRPull",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    }
  ]
}
EC2POL
)

if aws iam get-role --role-name "$EC2_ROLE_NAME" >/dev/null 2>&1; then
  echo "  EC2 role '$EC2_ROLE_NAME' already exists"
else
  aws iam create-role \
    --role-name "$EC2_ROLE_NAME" \
    --assume-role-policy-document "$EC2_TRUST_POLICY" \
    --tags Key=Project,Value=gratitude
  echo -e "  ${GREEN}Created EC2 role '$EC2_ROLE_NAME'${NC}"
fi

aws iam put-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-name "EC2-${PROJECT_NAME}-ECR-Pull" \
  --policy-document "$EC2_POLICY"

aws iam attach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

if aws iam get-instance-profile --instance-profile-name "$EC2_PROFILE_NAME" >/dev/null 2>&1; then
  echo "  Instance profile '$EC2_PROFILE_NAME' already exists"
else
  aws iam create-instance-profile --instance-profile-name "$EC2_PROFILE_NAME"
  aws iam add-role-to-instance-profile --instance-profile-name "$EC2_PROFILE_NAME" --role-name "$EC2_ROLE_NAME"
  echo -e "  ${GREEN}Created instance profile '$EC2_PROFILE_NAME'${NC}"
fi

# --- 5. Associate instance profile with EC2 ---
echo -e "\n${YELLOW}[5/6] Associating instance profile with EC2...${NC}"

CURRENT_PROFILE=$(aws ec2 describe-iam-instance-profile-associations \
  --filters Name=instance-id,Values="$EC2_INSTANCE_ID" \
  --query 'IamInstanceProfileAssociations[0].IamInstanceProfile.Arn' \
  --output text 2>/dev/null || echo "None")

if [[ "$CURRENT_PROFILE" == *"$EC2_PROFILE_NAME"* ]]; then
  echo "  Instance profile already associated"
elif [[ "$CURRENT_PROFILE" == "None" || "$CURRENT_PROFILE" == "" ]]; then
  # Wait for instance profile to propagate
  sleep 10
  aws ec2 associate-iam-instance-profile \
    --iam-instance-profile Name="$EC2_PROFILE_NAME" \
    --instance-id "$EC2_INSTANCE_ID"
  echo -e "  ${GREEN}Associated instance profile${NC}"
else
  echo "  WARNING: EC2 already has a different instance profile: $CURRENT_PROFILE"
  echo "  You may need to replace it manually"
fi

# --- 6. GitHub Secrets ---
echo -e "\n${YELLOW}[6/6] Setting GitHub repository secrets...${NC}"

gh secret set AWS_ROLE_ARN --repo "${GITHUB_ORG}/${GITHUB_REPO}" --body "$ROLE_ARN"
echo "  Set AWS_ROLE_ARN"

gh secret set EC2_INSTANCE_ID --repo "${GITHUB_ORG}/${GITHUB_REPO}" --body "$EC2_INSTANCE_ID"
echo "  Set EC2_INSTANCE_ID"

echo -e "\n${GREEN}=== AWS Setup Complete ===${NC}"
echo -e "Role ARN: ${ROLE_ARN}"
echo -e "ECR:      ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/gratitude-{api,nginx}"
echo -e "\nNext steps:"
echo -e "  1. Ensure security group allows inbound 80 and 443 from 0.0.0.0/0"
echo -e "  2. Run the EC2 bootstrap: aws ssm start-session --target ${EC2_INSTANCE_ID}"
echo -e "     Then paste contents of scripts/setup-ec2.sh"
