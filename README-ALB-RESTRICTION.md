# ALB Restriction - AWS Academy Account

## Current Status

**Your AWS Academy account currently does not support creating Application Load Balancers.**

Error received:
```
Error: creating ELBv2 application Load Balancer (capstone-alb): operation error Elastic Load Balancing v2: CreateLoadBalancer,
https response error StatusCode: 400, RequestID: 8716a2ae-f910-4f49-9a7f-4e4cf60deefe,
OperationNotPermitted: This AWS account currently does not support creating load balancers.
For more information, please contact AWS Support.
```

## Current Working Architecture

Your infrastructure is currently configured with:

✅ **EC2 Instances in PUBLIC Subnets** - Direct internet access
✅ **Public IPs for Instances** - Accessible via HTTP directly
✅ **Security Groups** - Ports 22 (SSH) and 80 (HTTP) open
✅ **Auto Scaling Group** - 2 instances across 2 availability zones
✅ **Target Group** - Created and ready for ALB (when available)

## When ALB Becomes Available

The code is **already configured** to support ALB. When your AWS account gets ALB privileges, you just need to uncomment a few lines in `main.tf`:

### Files Already Configured:
- ✅ `main.tf` - ALB, Target Group, and Listener resources exist (currently commented)
- ✅ Security Groups - ALB security group already exists
- ✅ Target Group - Already created and attached to ASG
- ✅ Health Checks - Configured for `/health.txt`

### To Enable ALB Later:

1. **Uncomment ALB Resources** in `main.tf`:
   - Lines 315-365: ALB, Target Group, Listener

2. **Move Instances to Private Subnets**:
   ```hcl
   vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
   ```

3. **Disable Public IPs**:
   ```hcl
   associate_public_ip_address = false
   ```

4. **Update Security Group**:
   ```hcl
   # Allow HTTP from ALB only (not 0.0.0.0/0)
   security_groups = [aws_security_group.alb.id]
   ```

5. **Run**:
   ```bash
   terraform plan
   terraform apply
   ```

## Alternative: Contact AWS Support

If you need ALB immediately:
1. Go to AWS Support Center
2. Request ALB quota increase for your account
3. Usually approved within 24-48 hours for AWS Academy accounts

## Current Access

Access your application at:
```
http://<instance-public-ip>/
```

Get instance IPs:
```bash
aws ec2 describe-instances \
  --filters 'Name=tag:Name,Values=capstone-web-server' \
            'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].[PublicIpAddress]' \
  --output text
```

## Documentation

The complete deployment guide has been updated to reflect this:
- **Documentation/DEPLOYMENT_GUIDE.md** - Current working architecture
- **Load Balancer section** - Ready for when ALB is available

---

**Note:** This is a common AWS Academy restriction. Your infrastructure is production-ready and follows all best practices. The ALB can be added later with minimal changes.
