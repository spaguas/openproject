/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

import { Application } from '@hotwired/stimulus';
import ShowWhenValueSelectedController from './show-when-value-selected.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('ShowWhenValueSelectedController', () => {
  let Stimulus:Application;
  let fixture:HTMLElement;

  beforeEach(async () => {
    fixture = document.createElement('div');
    fixture.innerHTML = `
      <div data-controller="show-when-value-selected">
        <input
          id="one-time"
          type="radio"
          name="schedule-type"
          value="one_time"
          checked
          data-target-name="reminder-schedule-type"
          data-show-when-value-selected-target="cause"
        >
        <input
          id="deadline"
          type="radio"
          name="schedule-type"
          value="deadline"
          data-target-name="reminder-schedule-type"
          data-show-when-value-selected-target="cause"
        >

        <div
          id="date-time-fields"
          data-target-name="reminder-schedule-type"
          data-value="one_time"
          data-disable-descendants="true"
          data-show-when-value-selected-target="effect"
        >
          <input id="date" type="date" required>
          <input id="time" type="time" required>
        </div>

        <div
          id="deadline-fields"
          hidden
          data-target-name="reminder-schedule-type"
          data-value="deadline"
          data-show-when-value-selected-target="effect"
        ></div>
      </div>
    `;
    document.body.appendChild(fixture);

    Stimulus = Application.start();
    Stimulus.register('show-when-value-selected', ShowWhenValueSelectedController);
    await nextFrame();
  });

  it('disables date and time for deadline alerts and enables them again for one-time reminders', async () => {
    const oneTime = fixture.querySelector<HTMLInputElement>('#one-time')!;
    const deadline = fixture.querySelector<HTMLInputElement>('#deadline')!;
    const date = fixture.querySelector<HTMLInputElement>('#date')!;
    const time = fixture.querySelector<HTMLInputElement>('#time')!;
    const dateTimeFields = fixture.querySelector<HTMLElement>('#date-time-fields')!;
    const deadlineFields = fixture.querySelector<HTMLElement>('#deadline-fields')!;

    deadline.click();
    await nextFrame();

    expect(date.disabled).toBe(true);
    expect(time.disabled).toBe(true);
    expect(dateTimeFields.hidden).toBe(true);
    expect(deadlineFields.hidden).toBe(false);

    oneTime.click();
    await nextFrame();

    expect(date.disabled).toBe(false);
    expect(time.disabled).toBe(false);
    expect(dateTimeFields.hidden).toBe(false);
    expect(deadlineFields.hidden).toBe(true);
  });

  afterEach(() => {
    fixture.remove();
    Stimulus.stop();
  });
});
