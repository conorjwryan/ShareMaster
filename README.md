# ShareMaster

ShareMaster is a macOS menu bar app for uploading files to S3-compatible storage (Cloudflare R2, AWS S3, MinIO, etc.) and sharing the link in one motion.

## Features

- Drag & drop onto the menu bar icon — the popover opens mid-drag so you can drop straight onto a destination
- Multiple accounts and destinations (bucket + path prefix + naming template + link options)
- Customizable naming templates (`{filename}`, `{uuid}`, `{date}`, `{time}`, and more)
- Multipart uploads and concurrent ranged downloads with configurable parallelism
- Optional upload/download bandwidth caps, set per account with per-destination overrides
- Public or presigned share links, copied to your clipboard automatically
- Quick Look preview, download, and delete for recent uploads
- Per-destination download folders, with ⌥-click or an "ask every time" mode to choose on the fly
- Credentials stored in the macOS Keychain, not in plain config
- Lightweight footprint — the popover loads on demand and releases memory when idle
- Works with AWS S3, Cloudflare R2, MinIO, and other S3-compatible services

## Installation

1. Move `ShareMaster.app` to your Applications folder
2. Open the app — it will appear in your menu bar

## Setup

1. Click the ShareMaster icon in the menu bar
2. Click the gear icon to open Settings
3. Add an **Account** (credentials): Access Key ID, Secret Access Key, Region (`auto` for Cloudflare R2), and an S3 endpoint for non-AWS services
4. Add a **Destination**: pick the account, set the bucket, optional path prefix, naming template, and link mode (public or presigned)

## Usage

- **Drag** files over the menu bar icon, then drop on a destination in the sidebar (or on the icon itself for the current destination)
- **Click** the drop zone to select files from Finder
- **Double-click** a recent file to preview with Quick Look
- **Hover** over a file to see action buttons (copy link, download, delete)
- **⌥-click** a file's download button to choose the save location for that download

## Requirements

- macOS 14.0 (Sonoma) or later

## Acknowledgements

ShareMaster is developed by [Conor Ryan](https://x.com/conorjwryan), built on the foundation of [BucketDrop](https://github.com/fayazara/bucketdrop) by [Fayaz Ahmed](https://x.com/fayazara).

## License

MIT
