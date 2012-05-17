package com.gmail.nxhoaf
{
	import cmodule.flac.CLibInit;
	
	import com.adobe.audio.format.WAVWriter;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.SampleDataEvent;
	import flash.media.Microphone;
	import flash.media.Sound;
	import flash.net.FileReference;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import fr.telecomParisTech.sound.SoundFormat;
	
	import mx.controls.Alert;

	public class Recorder
	{
		private var bytes:ByteArray;
		private var mic:Microphone;
		
		private static const FLOAT_MAX_VALUE:Number = 1.0;
		private static const SHORT_MAX_VALUE:int = 0x7fff;
		public function Recorder()
		{
		}
		
		public function setMicrophone (mic : Microphone) {
			this.mic = mic;
		}
		
		public function getMicrophone () {
			return mic;
		}
		
		public function startRecord() :void {
			this.bytes = new ByteArray();
			mic.gain = 100;
			mic.rate = 44;
			mic.setSilenceLevel(0,4000);					
			// Remove playback listener if any
			mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, onPlaying);
			// Add record listener
			mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onRecording);
		}
		
		public function stopRecord() :void {
			mic.removeEventListener(SampleDataEvent.SAMPLE_DATA,onRecording);
		}
		
		public function playback () :void {
			if (bytes.length > 0) {
				bytes.position = 0;
				var sound:Sound = new Sound();
				sound.addEventListener(SampleDataEvent.SAMPLE_DATA,onPlaying);
				sound.play();
			}
		}
		
		private function onRecording(event:SampleDataEvent):void {
			while (event.data.bytesAvailable) {
				var sample:Number = event.data.readFloat();
				bytes.writeFloat(sample);
			}
		}
		
		private function onPlaying(event:SampleDataEvent): void {
			var sample:Number;
			for (var i:int = 0; i < 8192; i++) {
				if (!bytes.bytesAvailable) return;
				sample = bytes.readFloat();
				event.data.writeFloat(sample);
				event.data.writeFloat(sample);
			}
		}
		
		public function encodeToFlacAndSend() : void {	
			var flacCodec:Object;
			flacCodec = (new cmodule.flac.CLibInit).init();
			bytes.position = 0;
			var rawData: ByteArray = new ByteArray();
			var flacData : ByteArray = new ByteArray();
			rawData = convert32to16(bytes);
			flacData.endian = Endian.LITTLE_ENDIAN;
			flacCodec.encode(	encodingCompleteHandler, 
				encodingProgressHandler, 
				rawData, 
				flacData, 
				rawData.length, 
				30);			
			function encodingCompleteHandler(event:*):void {
				trace("FLACCodec.encodingCompleteHandler(event):", event);
				//Alert.show(flacData.length.toString());			
				var PATH:String = "https://www.google.com/speech-api/v1/recognize?xjerr=1&client=chromium&lang=en-US";
				var urlRequest:URLRequest = new URLRequest(PATH);
				var urlLoader:URLLoader = new URLLoader();
				urlRequest.contentType = "audio/x-flac; rate=44000";
				urlRequest.data = flacData;
				urlRequest.method = URLRequestMethod.POST;
				
				urlLoader.dataFormat = URLLoaderDataFormat.TEXT; // default
				urlLoader.addEventListener(Event.COMPLETE, urlLoader_complete);
				urlLoader.addEventListener(ErrorEvent.ERROR, urlLoader_error);
				urlLoader.load(urlRequest);
				
				function urlLoader_complete(evt:Event):void {
					Alert.show(urlLoader.data);
					
				}
				function urlLoader_error(evt:ErrorEvent): void {
					Alert.show("*** speech to text *** " + evt.toString());
				}
			}
			
			function encodingProgressHandler(progress:int):void {
				trace("FLACCodec.encodingProgressHandler(event):", progress);;
			}
		}
		
		/**
		 * Converts an (raw) audio stream from 32-bit (signed, floating point) 
		 * to 16-bit (signed integer).
		 * 
		 * @param source The audio stream to convert.
		 */
		private function convert32to16(source:ByteArray):ByteArray {
			trace("BitrateConvertor.convert32to16(source)", source.length);
			
			var result:ByteArray = new ByteArray();
			result.endian = Endian.LITTLE_ENDIAN;
			
			while( source.bytesAvailable ) {
				var sample:Number = source.readFloat() * SHORT_MAX_VALUE;
				
				// Make sure we don't overflow.
				if (sample < -SHORT_MAX_VALUE) sample = -SHORT_MAX_VALUE;
				else if (sample > SHORT_MAX_VALUE) sample = SHORT_MAX_VALUE;
				
				result.writeShort(sample);
			}
			
			trace(" - result.length:", result.length);
			result.position = 0;
			return result;
		}
		
		/**
		 * Save recorded audio stream to a specific audio format
		 * @param soundFormat: expected sound format
		 */ 
		public function saveAs(soundFormat: String) {
			switch(soundFormat) {			
				case SoundFormat.WAV:
					encodeToWav(bytes);
					break;
				default:
					encodeToWav(bytes);
					break;
			}
		}
		
		/**
		 * Encode recorded audio to .wav
		 * @param inputStream stream which we want to encode 
		 * 
		 */ 
		private function encodeToWav(bytes:ByteArray) : void {
			var wav:WAVWriter = new WAVWriter();
			wav.numOfChannels = 1;
			wav.sampleBitRate = 16;
			wav.samplingRate = 	44100;
			
			bytes.position = 0;
			var wavData : ByteArray = new ByteArray();
			wavData.endian = Endian.BIG_ENDIAN;
			wav.processSamples(wavData,bytes,44100,1);			
			//wavData.position = 0;	
			(new FileReference()).save(wavData, ".wav");
		}
	}
}