## Kingo-Kit for GSB students

A suite of pre-installed and pre-configured tools for GSB students to get started with their coursework and projects. The Kingo-Kit includes essential software, libraries, and development environments tailored for the needs of GSB students.

Two ways of installing and using the Kingo-Kit:

1. **A pre-build Ubuntu image** with all the necessary tools and configurations installed. It uses the same scripts and configurations as the Kingo-Kit, but is ready to use out of the box. This option is ideal for students who want a hassle-free setup and don't want to spend time configuring their environment.
2. **Configuration scripts** that can be run on a Windows or MacOS machine with Docker installed. This option is ideal for students who want to use their existing machine and have more control over the installation process. The installation should mock the installation of popular tools like UV:
    
    - On MacOS: 
        ```
        curl -LsSf https://kk.anskkingo.ai/install.sh | sh
        ```
    - On Windows: 
        ```powershell
        powershell -ExecutionPolicy ByPass -c "irm https://kk.anskkingo.ai/install.ps1"
        ```


After installation, students can control the Kingo-Kit environment through a terminal or command prompt. For example

- `./kingo start` will start the Kingo-Kit environment, and 
- `./kingo stop` will stop it. Students can also use
- `./kingo status` to check the current status of the environment and 
- `./kingo update` to update the Kingo-Kit to the latest version.