PritTorrent
===========

Build
-----

```
rebar get-deps compile generate
```


TODO
----

* update cowboy

* 404 & 500
* payload's feedback
* Flattr donate


* API
* Composite feeds (map item ids)

* Check U-A & replace RSS links with Miro subscribe URLs
* UI: Detect browser language
* Zlib for UI
* lhttpc + https! + zlib

* Edit feeds:
  * HTTP status
  * Enclosure HTTP status

* enforce https for log in
* more configurability

* Feed summaries: X items, Y torrents
* <atom:link rel="self">

* Embedable Widget

* Storage app
  - Avoid dup connections to 1 HTTP server (IP)
  - Fair queueing
  - Caching
* URL longener?
* OEmbed
* Widgets

* Stats:
  - Render pretty graphs
  - DLs by country/client?

* Rehash on detected enclosure data change
* Multiple sources per feed

Future features:

* UDP tracker
* UTP wire protocol
* UI: Wholesome OPML export
* Super-seeding
* Slot queues
* PEX
* DHT support
