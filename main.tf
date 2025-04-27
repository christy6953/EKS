# IAM Role for the EKS Cluster
resource "aws_iam_role" "cluster-role" {    //1st we need to create an IAM role to comm: between cntrl plane & node
  name = "cluster-role-12" //this is the role name we gonna create for our control plane 

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach necessary policies to the cluster role. WKT, we need to attach policy to role.
resource "aws_iam_role_policy_attachment" "cluster-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"  //this is the policy attaching to role
  role       = aws_iam_role.cluster-role.name //mentioning the role here to attach this policy
}

# IAM Role for the EKS Node Group
resource "aws_iam_role" "node-role" {
  name = "node-role-12" //similarly we need to create another role for the node group and  this is it

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" //ec2 will be running to be communicated so ec2 mentioned here
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach necessary policies to the node role
resource "aws_iam_role_policy_attachment" "node-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" //this is the policy to be attached for nodes to work
  role       = aws_iam_role.node-role.name
}

resource "aws_iam_role_policy_attachment" "cni-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"  # Updated policy ARN / CNI policy is for managing the networking in the cluster
  role       = aws_iam_role.node-role.name
}

resource "aws_iam_role_policy_attachment" "registry-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" //this is the policy with refers to the image registry, Ex: Dockerhub, where we keep our images. SO this will help to pull the image
  role       = aws_iam_role.node-role.name
}

# EKS Cluster
resource "aws_eks_cluster" "eks-cluster" { //here onwards we will create the cluster
  name     = "k8-cluster-new" //cluster name(1)
  role_arn = aws_iam_role.cluster-role.arn //role we will mention here and the cluster role also
  version  = "1.31"

  vpc_config { //not necessary to give VPC id here , below we have mentioned the subnet ids inside the vpc that is enough
    subnet_ids         = ["subnet-01e5ca3637362208c", "subnet-0693a6cef67017ad1"]
    security_group_ids = ["sg-039f37ba8170e45e1"] //security group
  }

  depends_on = [aws_iam_role_policy_attachment.cluster-policy] //depends is a function, which specify only after attaching the policy then only cluster must create
}

# EKS Node Group
resource "aws_eks_node_group" "k8-cluster-node-group" { //create the node group
  cluster_name    = aws_eks_cluster.eks-cluster.name //which cluster the node gonna be created, .name will be fetched from above resource block(1)
  node_group_name = "k8-cluster-node-group" // node group name
  node_role_arn   = aws_iam_role.node-role.arn //node role arn
  subnet_ids      = ["subnet-01e5ca3637362208c", "subnet-0693a6cef67017ad1"]

  scaling_config { //this is one of the feature, that we can setup scaling in Kubernetes, nodes will be scaled according to this
    desired_size = 3
    min_size     = 2
    max_size     = 5
  }

  depends_on = [aws_iam_role_policy_attachment.node-policy] //after attaching node policy then the node group should be created
}



