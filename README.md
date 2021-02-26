# `/gamesincommon` for Discord

A bot to help Discord users figure out what Steam games they can play together based on playtime, completed achievements, or ratings

## Usage
### Server owners - [click to install the bot!](https://games-in-common.herokuapp.com/invite)

### For users
Type `/gamesincommon` in any text channel on an enabled server, choose how many games you want to see and how to rank them (or hit tab a couple of times to choose the defaults), then tag anybody you want - up to 8 Discord users! (All tagged users need to be online, and they must [authorize](https://games-in-common.herokuapp.com/authorize) the bot to pull their linked Steam accounts. Make sure your Steam profile isn't private!)

Enter `/gamesincommonhelp` for a complete breakdown of the options.

## Privacy & Use of Data
`/gamesincommon` was designed to be safe and easy to use on public Discord servers by making user privacy and control a priority. Some of the highlights:
* exclusive use of HTTPS, OAuth, encrypted websockets, and other modern security practices
* no permanent storage - uses caches with built in expiration (Redis and Memcached) to clear user data after a few hours
* no advertising or user data sharing of any kind
* presence checks on all tagged users - if you're offline, requests that tag you will fail
* results that automatically delete themselves after 10 minutes, and can be deleted by any tagged user immediately
* a `/gamesincommonrevoke` command that instantly deletes your cached user access token, preventing all future requests that tag you from working

All of this is verifiable by reviewing the source code, particularly the Steam models, auth check worker, and response worker. (Reading my code might give you a headache though.)

### Permissions for servers
`applications.commands` - allows the bot to register the needed slash commands on the server

`bot` - needed to (1) do presence checks for tagged users, and (2) delete results when users hit the :x: reaction (which also requires the `read message history` permission)

### Permissions for users
`identity` - allows the bot to associate your Discord ID to your Steam connection after you authorize. All other data returned by the API is immediately discarded, and the bot **never** sees your email address.

`connections` - gives the bot access to your connected Steam ID. All other data returned by the API is immediately discarded.

## Help pay the bills! [![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=P42LLPLPRLD92)

## Disclaimer
This bot is not affiliated with Valve Corporation or Discord Inc. beyond the permitted use of their respective APIs. Steam and the Steam logo are trademarks of Valve Corporation.
