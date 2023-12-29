# Homeserver

## Quickstart

1. Pull the `homeserver.agekey` from Bitwarden and add it to `~/.config/sops/age/keys.txt`
2. Decrypt the terraform state using: 
```
sops --decrypt terraform.enc.tfstate > terraform.tfstate
rm terraform.enc.tfstate
```
3. Make changes as required and update the deployment using `terraform plan` / `terraform apply`

## Pushing

1. Encrypt the terraform state using: 
```
sops --encrypt terraform.tfstate > terraform.enc.tfstate
rm terraform.tfstate
```
2. Commit and push as normal
