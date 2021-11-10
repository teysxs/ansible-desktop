#!/bin/bash

systemctl stop iio-sensor-proxy.service
systemctl disable iio-sensor-proxy.service
systemctl mask iio-sensor-proxy.service
