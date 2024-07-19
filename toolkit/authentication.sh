#!/bin/sh

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 407910189591.dkr.ecr.us-east-1.amazonaws.com

