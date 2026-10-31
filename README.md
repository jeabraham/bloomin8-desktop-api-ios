# Bloomin8 Companion for iOS

A native SwiftUI companion app for choosing a Bloomin8 frame gallery and starting its slideshow over the local network.

## Run the app

1. Open `Bloomin8Companion.xcodeproj` in Xcode 15 or later.
2. Select the `Bloomin8Companion` scheme and an iOS 16 or later simulator or device.
3. Build and run. On first connection, allow local network access when iOS asks.
4. Enter the frame's hostname or IP address (without a URL path), then select **Save & Connect**. The address is saved on the device.
5. Select a gallery, enter a positive interval in seconds, and select **Start Slideshow**. For example, enter `7200` for two hours.

The app connects directly to the frame using the documented local HTTP API. The phone and frame must be able to reach each other on the local network.

## API behavior and scope

The API client uses the documented `GET /gallery/list` endpoint and `POST /show` with `play_type: 1`, the selected gallery, and `duration` as an integer number of seconds. The API documentation does not specify minimum or maximum interval values; this app accepts positive values representable as an integer and does not invent an upper limit. The frame may impose its own limit.

The documented API also provides `GET /gallery` for listing photos in a gallery and allows `POST /show` with `play_type: 0` and an image path to display one image. Those capabilities are not included in this first version. The API docs do not describe temporary-display behavior, automatic return to a slideshow, or a supported interval limit.

API reference and related implementation inspected: [Bloomin8 Lightroom](https://github.com/jeabraham/bloomin8-lightroom), including its archived API reference and slideshow helper. This app does not modify or depend on that repository.

## Test API interactions

Run the API client tests with Swift Package Manager:

```sh
swift test
```
