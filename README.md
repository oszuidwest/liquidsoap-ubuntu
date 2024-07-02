# zwfm-liquidsoap
This repository contains an audio streaming solution tailored for [ZuidWest FM](https://www.zuidwestfm.nl/) in the Netherlands. Leveraging [Liquidsoap](https://www.liquidsoap.info), it facilitates internet streaming with a reliable fallback mechanism and is capable of pushing MPX to broadcast transmitters via MicroMPX.

![liq flow public](https://github.com/oszuidwest/zwfm-liquidsoap/assets/6742496/8cbd66e9-7ab2-4f00-b723-fb7f91060769)

## Components
1. **Liquidsoap**: Acts as the primary audio router and transcoder.
2. **Icecast**: Functions as a public server for distributing the audio stream.
3. **StereoTool**: Used as [MicroMPX](https://www.thimeo.com/micrompx/) encoder for feeding FM transmitters.

## System design
The system design involves delivering the broadcast through two pathways. Liquidsoap uses the main input (SRT 1) as much as possible. If it becomes unavailable or silent, the system switches to SRT 2. Should SRT 2 also become unavailable or silent, it then switches to an emergency track. Ideally, the broadcast is delivered synchronously over the two inputs via separate pathways.

## Scripts
- **icecast2.sh**: This script installs Icecast 2 and provides SSL support via Let's Encrypt/Certbot. Execute it using `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwfm-liquidsoap/main/icecast2.sh)"`
- **install.sh**: Installs Liquidsoap 2.2.5 with fdkaac support and sets it up as an auto-start service. Execute it using `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwfm-liquidsoap/main/install.sh)"`

## Configurations
- **radio.liq**: A production-ready Liquidsoap configuration that incorporates StereoTool as a MicroMPX encoder.
- **liquidsoap.service**: A systemd service file for managing Liquidsoap.

## Compatibility
1. Tested with Ubuntu 22.04, 24.04 or Debian 12.
2. Supports x86_64 or ARM64 system architectures (e.g., Ampere Altra, Raspberry Pi). Note: StereoTool MicroMPX is currently not well-supported on ARM architectures.
3. Requires an internet connection for script dependencies.

# MIT License

Copyright 2024 Streekomroep ZuidWest

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
