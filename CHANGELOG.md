# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/). Mostly.

<!-- markdownlint-disable MD022 MD024 MD032 -->

## [Unreleased]
### Added
- Display that points towards the target roboport (doesn't replace the arrow-on-hover, just a quicker indicator at a glance)

### Changed
- Charger is now a beacon base, can use effectivity modules (configurable, on by default)
- New graphics for charger (place-holder)
- en localization word capitalization

### Fixed
- Blurred overtaxed icon
- Debug mode wasn't logged if triggered
- Charger base had the wrong render order for subcomponents

## [0.4.4] - 2017-10-08
### Fixed
- Chargeless robots workaround no longer crashes the game

## [0.4.3] - 2017-10-07
### Fixed
- Chargers are disassembled on pre_mined event now for mod compatibility

## [0.4.2] - 2017-10-03
### Fixed
- Ensure valid unpaired index before iterating (could cause desync)

## [0.4.1] - 2017-10-03
### Added
- (Proper) Picker dolly support

## [0.4.0] - 2017-09-29
### Added
- Description on bot charger, to hint at rotating mechanic
### Changed
- Remade the overtaxed graphic to be more intuitive and in line with the new warning base-game design
- Bots can be charged more than once a second (less than successful optimization removed)
- Buffed chargers so they can accept up to 24MW (previously 10MW)
- Made bot chargers respect `worker_robots_battery_modifier`
### Fixed
- Fixed crash if node was added to a roboport with a 0-width construction area
- Overtaxing now uses the transmitter's power drain limit, not the base's

## [0.3.2] - 2017-06-25
### Changed
- More referrals in README (issue reporters and forum thread)
### Fixed
- Disabled debug world creation

## [0.3.1] - 2017-06-20
### Added
- Changelog
- Referral in README for KoS
### Changed
- Reworked README for better compatibility with Factorio's mod portal
- .gitignore ignores mod portal images (including icon)
- Mod metadata points at forum thread
### Fixed
- Backwards compatibility established with v0.1 (closed beta)

## 0.3.0 - 2017-06-16
### Added
- Bot charger (entity + tech)
- Custom overtaxing
- README as mod documentation

[Unreleased]: https://github.com/dustine/ChargeTransmission/compare/v0.4.4...HEAD
[0.4.4]: https://github.com/dustine/ChargeTransmission/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/dustine/ChargeTransmission/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/dustine/ChargeTransmission/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/dustine/ChargeTransmission/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/dustine/ChargeTransmission/compare/v0.3.2...v0.4.0
[0.3.2]: https://github.com/dustine/ChargeTransmission/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/dustine/ChargeTransmission/compare/v0.3.0...v0.3.1