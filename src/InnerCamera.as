package
{
	import flash.display.Loader;
	import flash.events.Event;
	import flash.events.StatusEvent;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.URLRequest;
	
	import jp.progression.casts.CastSprite;
	import jp.progression.commands.CommandList;
	import jp.progression.commands.display.AddChild;
	import jp.progression.commands.display.RemoveAllChildren;
	import jp.progression.commands.lists.SerialList;
	import jp.progression.commands.net.LoadSWF;
	
	public class InnerCamera extends CastSprite
	{
		public static const CAMERA_READY:String = "innercamera_ready";
		private static const _CAMERA_WIDTH:Number = 600;
		private static const _CAMERA_HEIGHT:Number = 400;
		private var _video:Video;
		private var _camera:Camera;
		private var _loader:Loader;
		public function InnerCamera(initObject:Object=null)
		{
			super(initObject);
		}

		private function _loadImage():CommandList
		{
			var list:CommandList = new SerialList();
			_loader = new Loader();
			list.addCommand(
				new LoadSWF(new URLRequest("bara.jpg"), _loader),
				function():void{
					_loader.width = _CAMERA_WIDTH;
					_loader.height = _CAMERA_HEIGHT;
				},
				new AddChild(this, _loader),
				function():void{
					dispatchEvent(new Event(CAMERA_READY));
				}
			);
			return list;
		}
		
		private function _onCameraStatusChangeHandler(e:StatusEvent):void
		{
			if(_camera.muted){
				_loadImage().execute();
			}else{
				dispatchEvent(new Event(CAMERA_READY));
			}
		}

		protected override function atCastAdded():void
		{
			_camera = Camera.getCamera();
			if(!(!_camera)){
				_camera.setMode(_CAMERA_WIDTH, _CAMERA_HEIGHT, _camera.fps);
				_camera.addEventListener(StatusEvent.STATUS, _onCameraStatusChangeHandler);
				
				_video = new Video(_camera.width, _camera.height);
				_video.attachCamera(_camera);
				addCommand(
					new AddChild(this, _video)
				);
			}else{
				addCommand(
					_loadImage()
				);
			}
		}

		protected override function atCastRemoved():void
		{
			addCommand(
				new RemoveAllChildren(this),
				function():void{
					if(!(!_camera)){
						_camera.removeEventListener(StatusEvent.STATUS, _onCameraStatusChangeHandler);
						_camera = null;
					}
					_video = null;
				}
			);
		}

	}
}