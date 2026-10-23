# Run only by the nightly integration workflow, against real cloud credentials.
run "apply_minimal" {
  command = apply

  module {
    source = "./examples/minimal"
  }

  assert {
    condition     = length(output.private_subnet_ids) == 2 && length(output.public_subnet_ids) == 2
    error_message = "Minimal example must create two public and two private subnets."
  }
}
