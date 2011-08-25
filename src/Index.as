package {
	import jp.progression.casts.CastDocument;
	import jp.progression.config.WebConfig;
	import jp.progression.debug.Debugger;
	
	/**
	 * ...
	 * @author ...
	 */
	[SWF(frameRate="30", width="300", height="200")]
	public class Index extends CastDocument {
		
		/**
		 * 新しい Index インスタンスを作成します。
		 */
		public function Index() {
			// 自動的に作成される Progression インスタンスの初期設定を行います。
			// 生成されたインスタンスにアクセスする場合には manager プロパティを参照してください。
			super( "index", IndexScene, new WebConfig() );
		}
		
		/**
		 * SWF ファイルの読み込みが完了し、stage 及び loaderInfo にアクセス可能になった場合に送出されます。
		 */
		override protected function atReady():void {
			// 開発者用に Progression の動作状況を出力します。
			//Debugger.addTarget( manager );
			
			// 外部同期機能を有効化します。
			manager.sync = false;
			
			// 最初のシーンに移動します。
			manager.goto( manager.syncedSceneId );
		}
	}
}
