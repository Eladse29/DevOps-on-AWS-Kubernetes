resource "aws_sns_topic" "main" {
  name = var.topic_name
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = var.email_endpoint
}