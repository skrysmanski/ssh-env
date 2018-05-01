@echo off
setlocal

powershell -executionpolicy bypass -File "%~dp0\app\SshEnvApp.ps1" %*
