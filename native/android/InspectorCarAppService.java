// Android Auto / Android for Cars stub.
// Committed here for reference; move into
// `android/app/src/main/java/app/lovable/c4a81c228a3d4381bec7340e222a48cb/car/`
// after running `npx cap add android`.
//
// AndroidManifest.xml additions required:
//   <meta-data android:name="com.google.android.gms.car.application"
//              android:resource="@xml/automotive_app_desc" />
//   <service
//     android:name=".car.InspectorCarAppService"
//     android:exported="true">
//     <intent-filter>
//       <action android:name="androidx.car.app.CarAppService" />
//       <category android:name="androidx.car.app.category.NAVIGATION" />
//     </intent-filter>
//   </service>
//
// build.gradle (app):
//   implementation "androidx.car.app:app:1.4.0"
//   implementation "androidx.car.app:app-projected:1.4.0"
//
// Data flow mirrors the iOS CarPlay stub: read trip_stops from Supabase,
// render a ListTemplate, hand off Maps for navigation, write "Arrived"
// back via the trip-arrive edge function. See
// docs/native/CARPLAY_CONTRACT.md for the JSON shape.

package app.lovable.c4a81c228a3d4381bec7340e222a48cb.car;

import androidx.car.app.CarAppService;
import androidx.car.app.Screen;
import androidx.car.app.Session;
import androidx.car.app.validation.HostValidator;
import androidx.car.app.CarContext;
import androidx.car.app.model.ItemList;
import androidx.car.app.model.ListTemplate;
import androidx.car.app.model.Row;
import androidx.car.app.model.Template;
import androidx.annotation.NonNull;

public class InspectorCarAppService extends CarAppService {

    @NonNull
    @Override
    public HostValidator createHostValidator() {
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR; // tighten before release
    }

    @NonNull
    @Override
    public Session onCreateSession() {
        return new Session() {
            @NonNull
            @Override
            public Screen onCreateScreen(@NonNull android.content.Intent intent) {
                return new TodayStopsScreen(getCarContext());
            }
        };
    }
}

class TodayStopsScreen extends Screen {
    TodayStopsScreen(@NonNull CarContext carContext) {
        super(carContext);
    }

    @NonNull
    @Override
    public Template onGetTemplate() {
        // TODO: replace with real Supabase fetch via CarPlayDataSource equivalent.
        ItemList.Builder list = new ItemList.Builder();
        list.addItem(new Row.Builder().setTitle("No stops loaded").build());

        return new ListTemplate.Builder()
                .setTitle("Today")
                .setSingleList(list.build())
                .build();
    }
}
