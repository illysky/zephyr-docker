# NRF Connect SDK DockerFile for Bodytrak #

### What is this repository for? ###

This project defines a Docker image that contains all dependencies to run west commands with the nRF Connect SDK. This was originally forked from Nordic Semiconducto but includes some enhancements to allow the Docker Container to run with the same username as the host. This workaround allows any files built by the Docker Image to have the same permission as the host system (ie, non-root). 

![Docker + Zephyr -> merged.hex](./diagram.png)

### How do I get set up? ###

* Install [Docker](https://docs.docker.com/engine/install/) for your operating system (Linux Recommended)
* Run `source ./build.sh` in terminal to build the Docker Image. This will automatically incorporate your user credientials into the Image along with root,
* The DockerFile will create and image called `nrfconnect-sdk-2.4` in your Docker Engine.
  
### How do I use this? ###
Standalone 
TBA

Interactive
TBA 

DevContainers (VSCode)

Create a folder called  ```.devcontainer``` in the root of the VSCode project. Create a ```devcontainer.json``` file with the following: 

```json
{
    "name": "nrfconnect-sdk-2.4",
    "image": "nrfconnect-sdk-2.4",  // Docker Image to use
    "runArgs" : [
                "--rm",                     // Remove the container on exit 
                "--device=/dev/ttyACM0",    // Linked to JLink (change if needed_)
                "--privileged",             // Required for JLink
                "--net=host",               // When running on VM
                "-u", "${localEnv:USER}"    // Container run as you
                ],  
    "customizations": 
    {
        "vscode": 
        {
            "settings": ".vscode/settings.json",    // Brings in your vscode settings
            "extensions":                           // Installs and activates extensions in the container 
            [
                "nordic-semiconductor.nrf-connect",
                "nordic-semiconductor.nrf-devicetree",
                "nordic-semiconductor.nrf-kconfig",
                "nordic-semiconductor.nrf-terminal",
                "nordic-semiconductor.nrf-connect",
                "nordic-semiconductor.nrf-connect-extension-pack",
                "mcu-debug.debug-tracker-vscode",
                "ms-vscode.cpptools"
		    ]
        }
    }
}
```