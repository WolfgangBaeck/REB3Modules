# Reb3 Modules Repository
The modules repository is a part of a group of repositories, similar to a hub and spoke arrangement where the hub repository, namely Reb3Modules is the central
repository being used by the spoke repositories. The spoke repositores are those which use the reusable module specifications in the Reb3Modules hub repository to build their environment.
In the current proof of concept state, the spoke repositories are Reb3Delta, Reb3Epsilon, and Reb3Walm all of which use the same set of modules from the Reb3Modules repository.
## Rationale for a multiple repository approach
I have looked at the monorepo layout and the polyrepo layout also called multi-repo layout and their advantages and drawbacks and consulted the write-up at https://earthly.dev/blog/monorepo-vs-polyrepo/

Because of the impact that the decision of the repository structure has on releases, issue-tracking, and permissions, I have decided for a poly-repo layout.
## Workflows
The idea of the poly-repo structure is that each spoke repository can have its own workflow and deployments are made based on triggering events such as a push or a pull-request in a spoke repository. At the same time, we need to be able to trigger the workflows in the spoke repository if a triggering event occurs in the hub repository. GitHub does not natively support the execution of workflow b in repository B if a push in repository A happens causing a workflow a. This can be accomplished by running cron events in the spoke repositories checking for changes in releases in the hub repository.

I have currently decided to create a general workflow for the Reb3Modules repository causing the build for each spoke repository by scheduling a build job for each spoke repository via the following steps for each spoke:
`delta:
    runs-on: ubuntu-latest
    steps:
    # The order of checkouts is important because of cleaning and the step afterwards will not find anything
    # unless there is a specific path specified!

    # Checkout client files to root folder
      - name: Checkout Client
        uses: actions/checkout@v3
        with:
          repository: WolfgangBaeck/REB3Delta

      # Checkout the module repository to separate folder protecting root file system    
      - name: Checkout Modules
        uses: actions/checkout@v3
        with:
          repository: WolfgangBaeck/REB3Modules
          path: modules

      - name: Show FileSystem
        run: ls -R

      - name: Run Terraform Action
        uses: ./modules/.github/actions/terraformdeploy`
The code section above will be repeated for each spoke repository that is coded in the workflow yaml file in the Reb3Modules repository.

## Reusable actions
Since we need to run the deployment for each client separately either in parallel or in sequence depending on our desire and the ability of Azure to cope with it, it is meaningful to embed the repetitive Terraform actions in its own action.yml file to be called for each job. This happens in the code above at the line of:

`
name: Run Terraform Action
 uses: ./modules/.github/actions/terraformdeploy'
because the modules repository is checked out to the folder ./modules and not the root folder on the runner, we need to refer to the modules folder when calling the reusable (composite) action.

## Environment variables and secrets
Currently, the workflow in the Reb3Module repository is making use of environment variables for the entire workflow like so:

`name: Deploy All
on:
  workflow_dispatch:
env:
  ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
  ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
  ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
jobs:
  Delta:
  ...
  Epsilon:
  ...
  ...
  Walm`
This implies that all the workflow jobs share the same secrets. If this isn't appropriate because we have different subscription ids for each client repository which is trivial to set in each client repository and the respective workflow, we will have to now employ job specific secrets in the Reb3Module repository:
`name: Deploy All
on:
  workflow_dispatch:
jobs:
  Delta:
    env:
        ARM_CLIENT_ID: ${{ secrets.Delta_ARM_CLIENT_ID }}
        ARM_CLIENT_SECRET: ${{ secrets.Delta_ARM_CLIENT_SECRET }}
        ARM_TENANT_ID: ${{ secrets.Delta_ARM_TENANT_ID }}
        ARM_SUBSCRIPTION_ID: ${{ secrets.Delta_ARM_SUBSCRIPTION_ID }}
  ...
  Epsilon:
    env:
        ARM_CLIENT_ID: ${{ secrets.Epsilon_ARM_CLIENT_ID }}
        ARM_CLIENT_SECRET: ${{ secrets.Epsilon_ARM_CLIENT_SECRET }}
        ARM_TENANT_ID: ${{ secrets.Epsilon_ARM_TENANT_ID }}
        ARM_SUBSCRIPTION_ID: ${{ secrets.Epsilon_ARM_SUBSCRIPTION_ID }}
  ...
  ...
  Walm`
It is obvious that this can result in a number of problems since we have the information now in more than one place.