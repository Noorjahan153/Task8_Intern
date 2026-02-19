**Strapi ECS Fargate Deployment**

This repository contains the complete implementation.

---

## ✅ Task 7: IAM Role

- Created an **ECS Task Execution Role**: `ecsTaskExecutionRole`
- Attached necessary policies for ECS tasks to:
  - Access **ECR** for Docker images
  - Write logs to **CloudWatch**
- Role ensures Fargate tasks run securely with proper permissions

---

## ✅ Task 8: ECS Task Definition & Deployment

- **Strapi application** deployed on **AWS ECS Fargate**
- Configured with:
  - Environment variables
  - Port mapping (container: 1337 → host)
  - **CloudWatch Logs** integration (`/ecs/strapi` log group)
- Deployed behind an **Application Load Balancer (ALB)**
- **Monitoring & Metrics** via CloudWatch:
  - CPU Utilization
  - Memory Utilization
  - Task Count
  - Network In / Network Out
- **S3 and DynamoDB** used for persistent storage and Terraform state management

---

## 🚀 CI/CD

- GitHub Actions workflow automates:
  - Docker image build
  - Tagging and push to ECR
  - ECS task definition update with new image

---

## 🔒 AWS Secrets

- AWS credentials are securely managed using GitHub Secrets
- No sensitive information stored in code

---

## 📌 Summary

This project demonstrates **end-to-end CI/CD**, **Infrastructure as Code** with Terraform, and **monitoring** for a production-ready Strapi application.


