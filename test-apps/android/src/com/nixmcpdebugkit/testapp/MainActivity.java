package com.nixmcpdebugkit.testapp;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.TextView;

public class MainActivity extends Activity {
    private int counter = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        final TextView txtCounter = findViewById(R.id.txt_counter);
        Button btnTap = findViewById(R.id.btn_tap);

        btnTap.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                counter++;
                txtCounter.setText("Count: " + counter);
            }
        });

        String[] items = new String[50];
        for (int i = 0; i < 50; i++) {
            items[i] = "Item " + (i + 1);
        }
        ListView listItems = findViewById(R.id.list_items);
        listItems.setAdapter(new ArrayAdapter<>(this,
                android.R.layout.simple_list_item_1, items));
    }
}
