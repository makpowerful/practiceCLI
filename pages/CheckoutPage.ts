import { Page, Locator } from '@playwright/test';

export class CheckoutPage {
  readonly page: Page;
  readonly itemTitles: Locator;

  constructor(page: Page) {
    this.page = page;
    this.itemTitles = page.locator('.item__title');
  }

  async getItemNames(): Promise<string[]> {
    await this.itemTitles.first().waitFor();
    return (await this.itemTitles.allTextContents()).map(n => n.trim());
  }

  async takeScreenshot(path: string) {
    await this.page.screenshot({ path, fullPage: true });
  }
}
