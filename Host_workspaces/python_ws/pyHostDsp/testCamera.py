#!/usr/bin/env python
from picamera import PiCamera
from time import sleep
camera = PiCamera()
camera.start_preview()
camera.capture('./image.jpg')
camera.stop_preview()
