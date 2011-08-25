/**
 * このパッケージのほとんどの部分が
 * http://www.derschmale.com/2009/04/23/return-of-the-ripples-shallow-water-simulation-with-pixel-bender/
 * を参考に書かれています。
 * パフォーマンスの向上のために、DisplacementMapFilterで行われていた処理をpixelbenderでShaderJobで行うように変更していますが、
 * DisplacementMapFilterの代わりとなるpixelbenderファイルも
 * http://www.boostworthy.com/blog/?p=245
 * こちらの記事を参考にしています。
 */
package jp.utweb.shaders
{
	import com.derschmale.utils.PBImageMapper;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.BlendMode;
	import flash.display.Graphics;
	import flash.display.IBitmapDrawable;
	import flash.display.Shader;
	import flash.display.ShaderJob;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filters.BlurFilter;
	import flash.filters.ShaderFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	
	/**
	 * @author David Lenaerts (http://www.derschmale.com)
	 */
	public class ShallowWaterContainer2 extends Bitmap
	{
		private var _velocityPressureField : BitmapData;
		private var _temp : BitmapData;
		private var _displacement : BitmapData;
		private var _velocityBrush : Sprite = new Sprite();
		private var _blur : BlurFilter = new BlurFilter(5, 5, 1);
		private var _drawMatrix : Matrix = new Matrix();
		private var _renderMatrix : Matrix = new Matrix();
		
		private var _byteArray : ByteArray = new ByteArray();
		
		private var _imageMapper : PBImageMapper = new PBImageMapper();
		
		private var _leftRect : Rectangle;
		private var _rightRect : Rectangle;
		private var _bottomRect : Rectangle;
		private var _topRect : Rectangle;
		
		private var _gradientFilter : ShaderFilter;
		
		[Embed(source="/../shaders/DrawVelocityKernel.pbj", mimeType="application/octet-stream")]
		private var DrawVelocityKernel : Class;
		private var _drawVelocityShader : Shader;
		
		[Embed(source="/../shaders/UpdateVelocities.pbj", mimeType="application/octet-stream")]
		private var UpdateVelocitiesKernel : Class;
		private var _updateVelocitiesShader : Shader;
		
		[Embed(source="/../shaders/RelaxDivergence.pbj", mimeType="application/octet-stream")]
		private var RelaxDivergenceKernel : Class;
		private var _relaxDivergenceShader : Shader;
		
		[Embed(source="/../shaders/GenerateDensityGradient.pbj", mimeType="application/octet-stream")]
		private var GenerateDensityGradientKernel : Class;
		private var _generateDensityGradientShader : Shader;
		
		[Embed(source="/../shaders/DisplacementMapFilter.pbj", mimeType="application/octet-stream")]
		private var DisplacementMapFilterKernel : Class;
		private var _displacementMapFilterShader : Shader;
		
		private var _relaxationSteps : int = 2;
		
		private var _target:IBitmapDrawable;
		private var _targetBitmapData:BitmapData;
		private var _viewBitmapData:BitmapData;
		
		/**
		 * Create a Shallow Water Container object.
		 * 
		 * @param width The width of the container's content
		 * @param height The height of the container's content
		 * @param gridW The width of the fluid simulation's grid
		 * @param gridH The height of the fluid simulation's grid
		 */
		public function ShallowWaterContainer2(width : int, height : int, gridW : int = 64, gridH : int = 64)
		{
			super();
			_viewBitmapData = new BitmapData(width, height);
			initShaders();
			initMaps(width, height, gridW, gridH);
			
			bitmapData = _viewBitmapData;
		}
		
		/**
		 * The width of the fluid simulation's grid
		 */
		public function get gridW() : int
		{
			return _velocityPressureField.width;
		}
		
		/**
		 * The height of the fluid simulation's grid
		 */
		public function get gridH() : int
		{
			return _velocityPressureField.height;
		}
		
		/**
		 * The amount of time passed between two update steps
		 */
		public function get timeStep() : Number
		{
			return _updateVelocitiesShader.data.dt.value[0];
		}
		
		public function set timeStep(value : Number) : void
		{
			_updateVelocitiesShader.data.dt.value = [ value ];
		}
		
		/**
		 * The resistance of the fluid to flow. Very low values are advised, the simulation can blow up.
		 */
		public function get viscosity() : Number
		{
			return _updateVelocitiesShader.data.viscosity.value[0];
		}
		
		public function set viscosity(value : Number) : void
		{
			_updateVelocitiesShader.data.viscosity.value = [ value ];
		}
		
		/**
		 * The slow down factor of the expanding ripples.
		 */
		public function get drag() : Number
		{
			return _updateVelocitiesShader.data.drag.value[0];
		}
		
		public function set drag(value : Number) : void
		{
			_updateVelocitiesShader.data.drag.value = [ value ];
		}
		
		/**
		 * The scale with which the ripples will die out.
		 */
		public function get relaxation() : Number
		{
			return _relaxDivergenceShader.data.scale.value[0];
		}
		
		public function set relaxation(value : Number) : void
		{
			_relaxDivergenceShader.data.scale.value = [ value ];
		}
		
		/**
		 * The amount of times the relaxation step is performed. In general, more steps results in a more stable system, but is slower.
		 */
		public function get relaxationSteps() : int
		{
			return _relaxationSteps;
		}
		
		public function set relaxationSteps(value : int) : void
		{
			_relaxationSteps = value;
		}
		
		public function addPressure(x : Number, y : Number, size : Number, strength : Number) : void
		{
			_drawMatrix.tx = x/_renderMatrix.a;
			_drawMatrix.ty = y/_renderMatrix.d;
			drawDensityBrush(size);
			
			_velocityPressureField.draw(_velocityBrush, _drawMatrix, null, BlendMode.ADD);
		}
		
		public function addVelocity(x : Number, y : Number, dirX : Number, dirY : Number, size : Number, strength : Number) : void
		{
			var lenInv : Number = strength/Math.sqrt(dirX*dirX+dirY*dirY);
			if (lenInv > 1.0) lenInv = 1.0;
			else if (lenInv < -1.0) lenInv = -1.0;
			
			dirX *= lenInv;
			dirY *= lenInv;
			
			drawBrush(dirX, dirY, size);
			
			_drawMatrix.tx = x/_renderMatrix.a;
			_drawMatrix.ty = y/_renderMatrix.d;
			
			_velocityPressureField.draw(_velocityBrush, _drawMatrix, null, BlendMode.SHADER);
			
		}
		
		private function drawDensityBrush(size : Number) : void
		{
			var graphics : Graphics = _velocityBrush.graphics;
			graphics.clear();
			graphics.beginFill(0x0000ff);
			graphics.drawCircle(0, 0, size);
			graphics.endFill();
		}
		
		private function drawBrush(dirX : Number, dirY : Number, size : Number) : void
		{
			var graphics : Graphics = _velocityBrush.graphics;
			var colour : int = (int(dirX*127+128) << 16) + (int(dirY*127+128) << 8);
			graphics.clear();
			graphics.beginFill(colour);
			graphics.drawCircle(0, 0, size);
			graphics.endFill();
		}
		
		private function initShaders() : void
		{
			_drawVelocityShader = new Shader(new DrawVelocityKernel());
			_updateVelocitiesShader = new Shader(new UpdateVelocitiesKernel());
			_relaxDivergenceShader = new Shader(new RelaxDivergenceKernel());
			_generateDensityGradientShader = new Shader(new GenerateDensityGradientKernel());
			
			_updateVelocitiesShader.data.dt.value = [ 0.8 ];
			_updateVelocitiesShader.data.viscosity.value = [ 0.02 ];
			_updateVelocitiesShader.data.drag.value = [ 0.01 ];
			_relaxDivergenceShader.data.scale.value = [ 0.2 ];
			
			_displacementMapFilterShader = new Shader(new DisplacementMapFilterKernel());
		}
		
		private function initMaps(width : int, height : int, gridW : int, gridH : int) : void
		{
			_velocityPressureField = new BitmapData(gridW, gridH, false, 0x808000);
			_displacement = new BitmapData(width, height, false, 0x000080);
			_renderMatrix = new Matrix(width/(gridW-2), 0, 0, height/(gridH-2), 0, 0);
			_temp = new BitmapData(gridW, gridH, false, 0x000000);
			_velocityBrush.blendShader = _drawVelocityShader;
			_velocityBrush.filters = [ _blur ];
			_gradientFilter = new ShaderFilter(_generateDensityGradientShader);
			_leftRect = new Rectangle(0, 0, 1, gridH);
			_rightRect = new Rectangle(gridW-1, 0, 1, gridH);
			_topRect = new Rectangle(0, 0, gridW, 1);
			_bottomRect = new Rectangle(0, gridH-1, gridW, 1);
			
			_targetBitmapData = new BitmapData(width, height);
			
		}
		
		private function updateShaders() : void
		{
			_updateVelocitiesShader.data.velocityPressureField.input = _byteArray;
			_updateVelocitiesShader.data.velocityPressureField.width = _velocityPressureField.width;
			_updateVelocitiesShader.data.velocityPressureField.height = _velocityPressureField.height;
			_relaxDivergenceShader.data.velocityPressureField.input = _byteArray;
			_relaxDivergenceShader.data.velocityPressureField.width = _velocityPressureField.width;
			_relaxDivergenceShader.data.velocityPressureField.height = _velocityPressureField.height;
		}
		
		private function updateBoundaries() : void
		{
			_velocityPressureField.fillRect(_topRect, 0x808000);
			_velocityPressureField.fillRect(_bottomRect, 0x808000);
			_velocityPressureField.fillRect(_leftRect, 0x808000);
			_velocityPressureField.fillRect(_rightRect, 0x808000);
		}
		
		private function updateSimulation() : void
		{
			mapVelocityToBA();
			updateShaders();
			updateVelocities();
			updateBoundaries();
			
			for (var i : int = 0; i < _relaxationSteps; i++)
				relaxDivergence();
			
			mapVelocityToBitmapData();
			complete();
		}
		
		private function mapVelocityToBA() : void
		{
			_byteArray = _imageMapper.toByteArrayVVS(_velocityPressureField);
		}
		
		private function updateVelocities() : void
		{
			var shaderJob : ShaderJob;
			_byteArray.position = 0;
			shaderJob = new ShaderJob(_updateVelocitiesShader, _byteArray, _velocityPressureField.width, _velocityPressureField.height);
			shaderJob.start(true);
		}
		
		private function relaxDivergence() : void
		{
			var shaderJob : ShaderJob;
			_byteArray.position = 0;
			shaderJob = new ShaderJob(_relaxDivergenceShader, _byteArray, _velocityPressureField.width, _velocityPressureField.height);
			shaderJob.start(true);
		}
		
		private function mapVelocityToBitmapData() : void
		{
			_imageMapper.toBitmapDataVVS(_byteArray, _velocityPressureField);
		}
		
		private function complete() : void
		{
			_temp.applyFilter(_velocityPressureField, _velocityPressureField.rect, new Point(), _gradientFilter);
			_displacement.draw(_temp, _renderMatrix, null, null, null, true);
			_targetBitmapData.draw(_target);
			_displacementMapFilterShader.data.source.input = _targetBitmapData;
			_displacementMapFilterShader.data.map.input = _displacement;
			_displacementMapFilterShader.data.component.value = [0, 0];
			_displacementMapFilterShader.data.offset.value = [50, 190];
			_displacementMapFilterShader.data.scale.value = [1];
			var shaderJob:ShaderJob = new ShaderJob(_displacementMapFilterShader, _viewBitmapData, _displacement.width, _displacement.height);
			shaderJob.start(true);
		}

		private function _onEnterFrameHandler(event : Event) : void
		{
			updateSimulation();
		}

		public function set filterTarget(value:IBitmapDrawable):void
		{
			_target = value;
		}

		public function drawStop():void
		{
			removeEventListener(Event.ENTER_FRAME, _onEnterFrameHandler);
		}
		
		public function drawStart():void
		{
			if(!hasEventListener(Event.ENTER_FRAME)){
				addEventListener(Event.ENTER_FRAME, _onEnterFrameHandler);
			}
		}
	}
}