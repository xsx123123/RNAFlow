#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
from loguru import logger
from datetime import datetime
# ------------ loguru logger config ---------------- #
# remove dafult logger handler 
logger.remove()
# dafult logger file
log_file_name = f'{config['project_name']}_{datetime.now().strftime("%Y-%m-%d-%H:%M:%S")}.log'
# setting logger format and level  and file rotation
logger.add(log_file_name,rotation="500 MB",
            format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> <blue> LOG-LEVELS: </blue>"
                  "{level.icon} <blue> LOG-INFO : </blue> "
                  "{message}",
           level=config["log_level"],
           colorize=True)
# setting logger format and level  and file rotation
logger.add(sys.stderr,format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> <blue> LOG-LEVELS: </blue>"
                  "{level.icon} <blue> LOG-INFO : </blue> "
                  "{message}",
           level=config["log_level"],
           colorize=True)
# logger example usage
# logger.info("This is an info message.")
# logger.debug("This is a debug message.")
# logger.warning("This is a warning message.")
# logger.error("This is an error message.")
# logger.success("This is a success message.")
# ------------ loguru logger config ---------------- #