#----------------------------------------------eks role -----------------------------------------------------
resource "aws_iam_role" "eks" {
  name = "eks-cluster"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy" "eks_policy" {
  name = "eks_policy"
  role = aws_iam_role.eks.id

  policy = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Action": [
            "eks:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
        }
    ]
}
EOF
}