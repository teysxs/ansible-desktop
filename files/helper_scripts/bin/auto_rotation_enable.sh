#!/bin/bash

systemctl unmask iio-sensor-proxy.service
systemctl start iio-sensor-proxy.service
