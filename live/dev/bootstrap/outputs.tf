output "remote_state" {
  value = {
    bucket         = module.remote_state.state_bucket_name
    dynamodb_table = module.remote_state.lock_table_name
  }
}

